# frozen_string_literal: true

module EE
  module Gitlab
    module Auth
      module Ldap
        module Sync
          class Group < ::Gitlab::Auth::Ldap::Sync::Base
            include ::GitlabSubscriptions::MemberManagement::PromotionManagementUtils

            attr_reader :provider, :group, :proxy

            class << self
              # Sync members across all providers for the given group.
              def execute_all_providers(group)
                return unless ldap_sync_ready?(group)

                begin
                  group.start_ldap_sync
                  ::Gitlab::AppLogger.debug "Started syncing all providers for '#{group.name}' group"

                  # Shuffle providers to prevent a scenario where sync fails after a time
                  # and only the first provider or two get synced. This shuffles the order
                  # so subsequent syncs should eventually get to all providers. Obviously
                  # we should avoid failure, but this is an additional safeguard.
                  ::Gitlab::Auth::Ldap::Config.providers.shuffle.each do |provider|
                    Sync::Proxy.open(provider) do |proxy|
                      new(group, proxy).update_permissions
                    end
                  end

                  group.finish_ldap_sync
                  ::Gitlab::AppLogger.debug "Finished syncing all providers for '#{group.name}' group"
                rescue ::Gitlab::Auth::Ldap::LdapConnectionError
                  ::Gitlab::AppLogger.warn("Error syncing all providers for '#{group.name}' group")
                  group.fail_ldap_sync
                end
              end

              # Sync members across a single provider for the given group.
              def execute(group, proxy)
                return unless ldap_sync_ready?(group)

                begin
                  group.start_ldap_sync
                  ::Gitlab::AppLogger.debug "Started syncing '#{proxy.provider}' provider for '#{group.name}' group"

                  sync_group = new(group, proxy)
                  sync_group.update_permissions

                  group.finish_ldap_sync
                  ::Gitlab::AppLogger.debug "Finished syncing '#{proxy.provider}' provider for '#{group.name}' group"
                rescue ::Gitlab::Auth::Ldap::LdapConnectionError
                  ::Gitlab::AppLogger.warn("Error syncing '#{proxy.provider}' provider for '#{group.name}' group")
                  group.fail_ldap_sync
                end
              end

              def ldap_sync_ready?(group)
                fail_stuck_group(group)

                return true unless group.ldap_sync_started?

                ::Gitlab::AppLogger.warn "Group '#{group.name}' is not ready for LDAP sync. Skipping"
                false
              end

              def fail_stuck_group(group)
                return unless group.ldap_sync_started?

                if group.ldap_sync_last_sync_at.nil?
                  fail_due_to_no_sync_time(group)
                elsif group.ldap_sync_last_sync_at < 1.hour.ago
                  group.mark_ldap_sync_as_failed('The sync took too long to complete.')
                end
              end

              def fail_due_to_no_sync_time(group)
                # If the group sync is in the started state but no sync
                # time was available, then something may be invalid with
                # this group. Do some validation and bubble up the error.
                details = group.errors.full_messages.join(', ') unless group.valid?

                message = +'The sync failed because the group is an inconsistent state'
                message += ": #{details}" if details

                group.mark_ldap_sync_as_failed(message, skip_validation: true)
              end
            end

            def initialize(group, proxy)
              @provider = proxy.provider
              @group = group
              @proxy = proxy
            end

            def update_permissions
              unless group.ldap_sync_started?
                logger.warn "Group '#{group.name}' LDAP sync status must be 'started' before updating permissions"
                return
              end

              access_levels = AccessLevels.new
              # Only iterate over group links for the current provider
              group.ldap_group_links.with_provider(provider).each do |group_link|
                next unless group_link.active?

                update_access_levels(access_levels, group_link)
              end

              # Users in this LDAP group may already have a higher access level in a parent group.
              # Currently demoting a user in a subgroup is forbidden by (Group)Member validation
              # so we must propagate any higher inherited permissions unconditionally.
              inherit_higher_access_levels(group, access_levels)

              logger.debug(
                <<-MSG.strip_heredoc.tr("\n", ' ')
                  Resolved '#{group.name}' group member access,
                  propagating any higher access inherited from a parent group:
                  #{access_levels.to_hash}
                MSG
              )

              update_existing_group_membership(group, access_levels)
              add_new_members(group, access_levels)
            end

            private

            def update_access_levels(access_levels, group_link)
              if member_dns = get_member_dns(group_link)
                access_levels.set(member_dns, to: { base_access_level: group_link.group_access, member_role_id: group_link.member_role_id })

                logger.debug "Resolved '#{group.name}' group member access: #{access_levels[:base_access_level]}"
              end
            end

            # for all LDAP Distinguished Names in access_levels, merge access level
            # with any higher permission inherited from a parent group
            def inherit_higher_access_levels(group, access_levels)
              return unless group.parent

              # for any permission granted by an ancestor group to any DN in access_levels,
              # retrieve user DN, and access_level.
              # Ignore unapproved access requests.
              permissions_in_ancestry = ::GroupMember.of_groups(group.ancestors).non_request

              permissions_in_ancestry.each_batch do |relation|
                members = relation.load

                identities = ::Identity
                  .with_provider(provider)
                  .iwhere(extern_uid: access_levels.keys)
                  .for_user_ids(members.map(&:user_id))
                  .group_by(&:user_id)

                members.each do |member|
                  identities_for_user = identities[member.user_id] || []

                  identities_for_user.each do |identity|
                    distinguished_name = identity.extern_uid

                    access_levels.set([distinguished_name], to: { base_access_level: member.access_level, member_role_id: member.member_role_id })
                  end
                end
              end
            end

            def update_existing_group_membership(group, access_levels)
              logger.debug "Updating existing membership for '#{group.name}' group"

              multiple_ldap_providers = ::Gitlab::Auth::Ldap::Config.providers.count > 1
              existing_members = select_and_preload_group_members(group)
              # For each existing group member, we'll need to look up its LDAP identity in the current LDAP provider.
              # It is much faster to resolve these at once than later for each member one by one.
              ldap_identity_by_user_id = resolve_ldap_identities(for_users: existing_members.map(&:user))

              existing_members.each do |member|
                user = member.user
                identity = ldap_identity_by_user_id[user.id]

                # Skip if this is not an LDAP user with a valid `extern_uid`.
                next unless identity.present? && identity.extern_uid.present?

                member_dn = identity.extern_uid

                # Prevent shifting group membership, in case where user is a member
                # of two LDAP groups from different providers linked to the same
                # GitLab group. This is not ideal, but preserves existing behavior.
                if multiple_ldap_providers && user.ldap_identity.id != identity.id
                  access_levels.delete(member_dn)
                  next
                end

                # Skip validations and callbacks. We have a limited set of attrs
                # due to the `select` lookup, and we need to be efficient.
                # Low risk, because the member should already be valid.
                member.update_column(:ldap, true) unless member.ldap?

                desired_access = access_levels[member_dn]

                # Check and update the access level. If `desired_access` is `nil`
                # we need to delete the user from the group.
                if desired_access.present?
                  # Delete this entry from the hash now that we're acting on it
                  access_levels.delete(member_dn)

                  # Don't do anything if the user already has the desired access level
                  # and respect existing overrides
                  next if member.access_level == desired_access || member.override?

                  add_or_update_user_membership(
                    user,
                    group,
                    desired_access
                  )
                elsif group.last_owner?(user)
                  warn_cannot_remove_last_owner(user, group)
                else
                  group.group_members.destroy(member.id)
                end
              end
            end

            def add_new_members(group, access_levels)
              logger.debug "Adding new members to '#{group.name}' group"

              return unless access_levels.present?

              # Even in the absence of new members, the list of DNs to add can be consistently large
              # when LDAP groups contain members who do not have a gitlab account.
              # Thus we can be a lot more efficient by pre-resolving all candidate DNs into gitlab users.
              gitlab_users_by_dn = resolve_users_from_normalized_dn(for_normalized_dns: access_levels.keys)

              access_levels.each do |member_dn, access_level|
                user = gitlab_users_by_dn[member_dn]

                if user.present?
                  add_or_update_user_membership(
                    user,
                    group,
                    access_level
                  )
                else
                  logger.debug(
                    <<-MSG.strip_heredoc.tr("\n", ' ')
                      #{self.class.name}: User with DN `#{member_dn}` should have access
                      to '#{group.name}' group but there is no user in GitLab with that
                      identity. Membership will be updated once the user signs in for
                      the first time.
                    MSG
                  )
                end
              end
            end

            def add_or_update_user_membership(user, group, access, current_user: nil)
              # Prevent the last owner of a group from being demoted
              if access[:base_access_level] < ::Gitlab::Access::OWNER && group.last_owner?(user)
                warn_cannot_remove_last_owner(user, group)
              else
                # If you pass the user object, instead of just user ID,
                # it saves an extra user database query.
                member = group.add_member(
                  user,
                  access[:base_access_level],
                  member_role_id: access[:member_role_id],
                  current_user: current_user,
                  ldap: true
                )

                trigger_event_to_promote_pending_members!(member)
              end
            end

            def warn_cannot_remove_last_owner(user, group)
              logger.warn(
                <<-MSG.strip_heredoc.tr("\n", ' ')
                  #{self.class.name}: LDAP group sync cannot remove #{user.name}
                  (#{user.id}) from group #{group.name} (#{group.id}) as this is
                  the group's last owner
                MSG
              )
            end

            # rubocop: disable CodeReuse/ActiveRecord
            def select_and_preload_group_members(group)
              group.members.select(:id, :access_level, :user_id, :ldap, :override)
                .with_identity_provider(provider).preload(:user)
                .allow_cross_joins_across_databases(url: "https://gitlab.com/gitlab-org/gitlab/-/issues/422405")
            end
            # rubocop: enable CodeReuse/ActiveRecord
          end
        end
      end
    end
  end
end
