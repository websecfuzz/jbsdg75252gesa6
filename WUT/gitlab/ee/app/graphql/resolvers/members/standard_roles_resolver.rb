# frozen_string_literal: true

module Resolvers
  module Members
    class StandardRolesResolver < BaseResolver
      include LooksAhead
      include ::GitlabSubscriptions::SubscriptionHelper
      include Gitlab::Graphql::Authorize::AuthorizeResource

      type Types::Members::StandardRoleType, null: true

      argument :access_level, [Types::MemberAccessLevelEnum],
        required: false,
        description: 'Access level or levels to filter by.'

      def resolve_with_lookahead(access_level: nil)
        access_levels(access_level)
          .map { |name, access_level| map_from(name, access_level) }
          .sort_by { |role| role[:access_level] }
      end

      def ready?(**args)
        return true if object

        raise_resource_not_available_error!('You have to specify group for SaaS.') if gitlab_com_subscription?

        super
      end

      private

      def member_counts
        selects_field?(:members_count) ? memberships([:id, :access_level]).count_members_by_role : {}
      end
      strong_memoize_attr :member_counts

      def user_counts
        selects_field?(:users_count) ? memberships([:id, :access_level, :user_id]).count_users_by_role : {}
      end
      strong_memoize_attr :user_counts

      def selected_fields
        node_selection.selections.map(&:name)
      end

      def selects_field?(name)
        lookahead.selects?(name) || selected_fields.include?(name)
      end

      def access_levels(target_access_levels)
        all_levels = Gitlab::Access.options_with_minimal_access
        return all_levels if target_access_levels.blank?

        all_levels.select { |_, level| target_access_levels.include?(level) }
      end

      def map_from(name, access_level)
        {
          name: name,
          access_level: access_level,
          members_count: member_counts[access_level] || 0,
          users_count: user_counts[access_level] || 0,
          group: object
        }
      end

      def memberships(columns)
        Member.with_static_role.for_self_and_descendants(object, columns)
      end
    end
  end
end
