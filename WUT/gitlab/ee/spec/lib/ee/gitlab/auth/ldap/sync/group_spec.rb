# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Gitlab::Auth::Ldap::Sync::Group, feature_category: :system_access do
  include LdapHelpers

  let_it_be(:adapter) { ldap_adapter }
  let_it_be(:user) { create(:user) }

  before do
    # We need to actually activate the LDAP config otherwise `Group#ldap_synced?`
    # will always be false!
    allow(Gitlab.config.ldap).to receive_messages(enabled: true)

    create(:identity, user: user, extern_uid: user_dn(user.username))

    stub_ldap_config(active_directory: false)
    stub_ldap_group_find_by_cn('ldap_group1', ldap_group1, adapter)
  end

  shared_examples 'group state machine' do
    it 'uses the ldap sync state machine' do
      expect(group).to receive(:start_ldap_sync)
      expect(group).to receive(:finish_ldap_sync)
      expect(described_class)
        .to receive(:new).at_most(:twice).and_call_original

      execute
    end

    it 'fails a stuck group older than 1 hour' do
      group.start_ldap_sync
      group.update_column(:ldap_sync_last_sync_at, 61.minutes.ago)

      expect(group).to receive(:mark_ldap_sync_as_failed)

      execute
    end

    context 'when the group ldap sync has already started' do
      it 'logs a debug message' do
        group.start_ldap_sync

        expect(Gitlab::AppLogger)
          .to receive(:warn)
                .with(/^Group '\w*' is not ready for LDAP sync. Skipping/)
                .at_least(:once)

        execute
      end

      it 'does not update permissions' do
        group.start_ldap_sync

        expect_any_instance_of(described_class)
          .not_to receive(:update_permissions)

        execute
      end
    end

    context 'when ldap connection fails' do
      before do
        unstub_ldap_group_find_by_cn
        raise_ldap_connection_error
      end

      it 'logs a debug message' do
        expect(Gitlab::AppLogger)
          .to receive(:warn).at_least(:once)

        execute
      end

      it 'ensures group state returns to failed_ldap_sync' do
        execute

        expect(group.ldap_sync_failed?).to be_truthy
      end
    end
  end

  shared_examples 'handles pending promotion memberships' do
    let(:license) { create(:license, plan: License::ULTIMATE_PLAN) }
    let!(:member_approval) do
      create(:gitlab_subscription_member_management_member_approval, :to_maintainer, user: user)
    end

    before do
      stub_application_setting(enable_member_promotion_management: true)
      allow(License).to receive(:current).and_return(license)
      allow(::Gitlab::EventStore).to receive(:publish).and_call_original
    end

    context 'when there are pending promotions' do
      it 'publishes MembershipModifiedByAdminEvent' do
        expect { sync_group.update_permissions }.to publish_event(::Members::MembershipModifiedByAdminEvent).with(
          {
            member_user_id: user.id
          }
        )
      end
    end

    context 'when there are no pending promotions' do
      let!(:member_approval) { nil }

      it 'does not publishes MembershipModifiedByAdminEvent' do
        expect { sync_group.update_permissions }.not_to publish_event(::Members::MembershipModifiedByAdminEvent)
      end
    end
  end

  describe '.execute_all_providers' do
    def execute
      described_class.execute_all_providers(group)
    end

    before do
      stub_ldap_config(providers: %w[ldapmain secundary])

      adapter = ldap_adapter('ldapmain')
      proxy = proxy(adapter, 'ldapmain')
      allow(EE::Gitlab::Auth::Ldap::Sync::Proxy).to receive(:open).and_yield(proxy)
    end

    let(:group) do
      create(:group_with_ldap_group_link,
        cn: 'ldap_group1',
        group_access: ::Gitlab::Access::DEVELOPER)
    end

    let(:ldap_group1) { ldap_group_entry(user_dn(user.username)) }

    include_examples 'group state machine'
  end

  describe '.execute' do
    def execute
      described_class.execute(group, proxy(adapter))
    end

    let(:group) do
      create(:group_with_ldap_group_link,
        cn: 'ldap_group1',
        group_access: ::Gitlab::Access::DEVELOPER)
    end

    let(:ldap_group1) { ldap_group_entry(user_dn(user.username)) }

    include_examples 'group state machine'
  end

  describe '.fail_stuck_group' do
    let(:ldap_group1) { ldap_group_entry(user_dn(user.username)) }

    it 'handles nil ldap_sync_last_sync_at' do
      group = create(:group_with_ldap_group_link,
        cn: 'ldap_group1',
        group_access: ::Gitlab::Access::DEVELOPER,
        ldap_sync_status: 'started',
        ldap_sync_last_sync_at: nil,
        visibility_level: Gitlab::VisibilityLevel::PUBLIC)
      create(:project, group: group, visibility_level: Gitlab::VisibilityLevel::PUBLIC)
      group.update_columns(visibility_level: Gitlab::VisibilityLevel::PRIVATE)

      expect(group).not_to be_valid

      described_class.fail_stuck_group(group)

      expect(group.ldap_sync_status).to eq('failed')
      expect(group.ldap_sync_error).to eq('The sync failed because the group is an inconsistent state: Visibility level private is not allowed since this group contains projects with higher visibility.')
    end
  end

  describe '.ldap_sync_ready?' do
    let(:ldap_group1) { nil }

    it 'returns false when ldap sync started' do
      group = create(:group)
      group.start_ldap_sync

      expect(described_class.ldap_sync_ready?(group)).to be_falsey
    end

    it 'returns true when ldap sync pending' do
      group = create(:group)
      group.pending_ldap_sync

      expect(described_class.ldap_sync_ready?(group)).to be_truthy
    end
  end

  describe '#update_permissions' do
    before do
      # Safe-check because some permissions are removed when `Group#ldap_synced?`
      # is true (e.g. in `GroupPolicy`).
      expect(group).to be_ldap_synced
      group.start_ldap_sync
    end

    after do
      group.finish_ldap_sync
    end

    let(:group) do
      create(:group_with_ldap_group_link,
        cn: 'ldap_group1',
        group_access: ::Gitlab::Access::DEVELOPER)
    end

    let(:sync_group) { described_class.new(group, proxy(adapter)) }

    context 'with all functionality against one LDAP group type' do
      context 'with basic add/update actions' do
        let(:ldap_group1) { ldap_group_entry(user_dn(user.username)) }

        it 'does not update permissions unless ldap sync status is started' do
          group.finish_ldap_sync

          expect(Gitlab::AppLogger)
            .to receive(:warn).with(/status must be 'started' before updating permissions/)

          sync_group.update_permissions
        end

        context 'when new membership is added' do
          it 'adds new members and sets ldap attribute to true' do
            sync_group.update_permissions

            expect(group.members.pluck(:user_id)).to include(user.id)
            expect(group.members.find_by(user_id: user.id).ldap?).to be_truthy
          end

          it_behaves_like 'handles pending promotion memberships'
        end

        it 'converts an existing membership access request to a real member' do
          group.add_owner(create(:user))
          access_requester = group.request_access(user)
          access_requester.update!(access_level: ::Gitlab::Access::MAINTAINER)
          # Validate that the user is properly created as a requester first.
          expect(group.requesters.pluck(:id)).to include(access_requester.id)

          sync_group.update_permissions

          expect(group.members.pluck(:id)).to include(access_requester.id)
          expect(group.members.find_by(user_id: user.id).access_level)
            .to eq(::Gitlab::Access::DEVELOPER)
        end

        it 'downgrades existing member access' do
          # Create user with higher access
          group.add_member(user, Gitlab::Access::MAINTAINER)

          sync_group.update_permissions

          expect(group.members.find_by(user_id: user.id).access_level)
            .to eq(::Gitlab::Access::DEVELOPER)
        end

        context  'when member access is upgraded' do
          before do
            # Create user with lower access
            group.add_member(user, Gitlab::Access::GUEST)
          end

          it 'upgrades existing member access' do
            sync_group.update_permissions

            expect(group.members.find_by(user_id: user.id).access_level)
              .to eq(::Gitlab::Access::DEVELOPER)
          end

          it_behaves_like 'handles pending promotion memberships'
        end

        it 'sets an existing member ldap attribute to true' do
          group.add_members(
            [user],
            ::Gitlab::Access::DEVELOPER
          )

          sync_group.update_permissions

          expect(group.members.find_by(user_id: user.id).ldap?).to be_truthy
        end

        it 'does not alter an ldap member that has a permission override' do
          group.members.create!(
            user: user,
            access_level: ::Gitlab::Access::MAINTAINER,
            ldap: true,
            override: true
          )

          sync_group.update_permissions

          expect(group.members.find_by(user_id: user.id).access_level)
            .to eq(::Gitlab::Access::MAINTAINER)
        end
      end

      context 'when existing user is no longer in LDAP group' do
        let(:ldap_group1) do
          ldap_group_entry(user_dn('some_user'))
        end

        it 'removes the group member' do
          group.add_member(user, Gitlab::Access::MAINTAINER)

          sync_group.update_permissions

          expect(group.members.find_by(user_id: user.id)).to be_nil

          # Sanity check that the user record is not deleted
          expect(User.find_by_id(user.id)).to be_present
        end

        it 'refuses to delete the last owner' do
          group.add_member(user, Gitlab::Access::OWNER)

          sync_group.update_permissions

          expect(group.members.find_by(user_id: user.id).access_level)
            .to eq(::Gitlab::Access::OWNER)
        end

        it 'updates projects authorizations', :sidekiq_inline do
          project = create(:project, namespace: group)
          group.add_member(user, Gitlab::Access::MAINTAINER)

          sync_group.update_permissions

          expect(project.authorized_users.find_by(id: user.id)).to be_nil
        end
      end

      context 'when the user is the last owner' do
        let(:user1) { create(:user) }
        let(:user2) { create(:user) }
        let(:ldap_group1) do
          ldap_group_entry(%W[#{user_dn(user1.username)} #{user_dn(user2.username)}])
        end

        it 'downgrades one user but not the other' do
          create(:identity, user: user1, extern_uid: user_dn(user1.username))
          create(:identity, user: user2, extern_uid: user_dn(user2.username))
          group.add_members([user1, user2], Gitlab::Access::OWNER)

          sync_group.update_permissions

          expect(group.members.pluck(:access_level).sort)
            .to eq([::Gitlab::Access::DEVELOPER, ::Gitlab::Access::OWNER])
        end
      end

      shared_examples 'inheritance from inherit_higher_access_levels' do
        context 'when user inherits higher permissions from parent' do
          let(:parent_group) { create(:group) }
          let(:ldap_group1) { ldap_group_entry(user_dn(user.username)) }

          before do
            group.update!(parent: parent_group)
            parent_group.add_maintainer(user)
          end

          it "adds member with the inherited higher permission" do
            sync_group.update_permissions

            expect(group.members.find_by(user_id: user.id).access_level)
              .to eq(::Gitlab::Access::MAINTAINER)
          end

          it "upgrades existing member to the inherited higher permission" do
            group.add_member(user, Gitlab::Access::DEVELOPER)

            sync_group.update_permissions

            expect(group.members.find_by(user_id: user.id).access_level)
              .to eq(::Gitlab::Access::MAINTAINER)
          end

          it "does not alter an ldap member that has a permission override" do
            group.members.create!(
              user: user,
              access_level: ::Gitlab::Access::OWNER,
              ldap: true,
              override: true
            )

            sync_group.update_permissions

            expect(group.members.find_by(user_id: user.id).access_level)
              .to eq(::Gitlab::Access::OWNER)
          end

          context 'and another member who does not inherit higher permissions' do
            let(:user2) { create(:user) }
            let(:ldap_group1) do
              ldap_group_entry(%W[#{user_dn(user.username)} #{user_dn(user2.username)}])
            end

            before do
              create(:identity, user: user2, extern_uid: user_dn(user2.username))
            end

            it 'upgrades user with the inherited higher permission but not the other' do
              group.add_members([user, user2], Gitlab::Access::DEVELOPER)

              sync_group.update_permissions

              expect(group.members.find_by(user_id: user.id).access_level)
                .to eq(::Gitlab::Access::MAINTAINER)
              expect(group.members.find_by(user_id: user2.id).access_level)
                .to eq(::Gitlab::Access::DEVELOPER)
            end
          end

          context 'and another member who also inherits higher permissions' do
            let(:user2) { create(:user) }
            let(:ldap_group1) do
              ldap_group_entry(%W[#{user_dn(user.username)} #{user_dn(user2.username)}])
            end

            before do
              create(:identity, user: user2, extern_uid: user_dn(user2.username))
              parent_group.add_owner(user2)
            end

            it 'upgrades both users with the inherited higher permissions' do
              group.add_members([user, user2], Gitlab::Access::DEVELOPER)

              sync_group.update_permissions

              expect(group.members.find_by(user_id: user.id).access_level)
                .to eq(::Gitlab::Access::MAINTAINER)
              expect(group.members.find_by(user_id: user2.id).access_level)
                .to eq(::Gitlab::Access::OWNER)
            end
          end
        end

        context 'when user inherits lower permissions from parent' do
          let(:parent_group) { create(:group) }
          let(:ldap_group1) { ldap_group_entry(user_dn(user.username)) }

          before do
            group.update!(parent: parent_group)
            parent_group.add_reporter(user)
          end

          it "adds member with the ldap group link's access level" do
            sync_group.update_permissions

            expect(group.members.find_by(user_id: user.id).access_level)
              .to eq(::Gitlab::Access::DEVELOPER)
          end

          it "downgrades existing member access to the ldap group link's access level" do
            group.add_member(user, Gitlab::Access::MAINTAINER)

            sync_group.update_permissions

            expect(group.members.find_by(user_id: user.id).access_level)
              .to eq(::Gitlab::Access::DEVELOPER)
          end

          it "does not alter an ldap member that has a permission override" do
            group.members.create!(
              user: user,
              access_level: ::Gitlab::Access::OWNER,
              ldap: true,
              override: true
            )

            sync_group.update_permissions

            expect(group.members.find_by(user_id: user.id).access_level)
              .to eq(::Gitlab::Access::OWNER)
          end
        end

        context 'when user has a pending access request in a parent group' do
          let(:parent_group) { create(:group) }
          let(:ldap_group1) { ldap_group_entry(user_dn(user.username)) }
          let(:access_requester) { parent_group.request_access(user) }

          before do
            group.update!(parent: parent_group)
            parent_group.add_owner(create(:user))
          end

          it 'does not propagate the access level of the pending access request' do
            group.members.create!(
              user: user,
              access_level: ::Gitlab::Access::DEVELOPER,
              ldap: true
            )
            access_requester.update!(access_level: ::Gitlab::Access::MAINTAINER)

            sync_group.update_permissions

            expect(parent_group.requesters.find_by(id: access_requester.id).access_level)
              .to eq(::Gitlab::Access::MAINTAINER)
            expect(group.members.find_by(user_id: user.id).access_level)
              .to eq(::Gitlab::Access::DEVELOPER)
          end
        end

        context 'when user inherits permissions from parent and user is no longer in LDAP group' do
          let(:parent_group) { create(:group) }
          let(:ldap_group1) { ldap_group_entry(user_dn('other_user')) }

          before do
            group.update!(parent: parent_group)
            parent_group.add_maintainer(user)
          end

          it "removes existing member" do
            group.add_member(user, Gitlab::Access::MAINTAINER)

            sync_group.update_permissions

            expect(group.members.find_by(user_id: user.id)).to be_nil

            # Sanity check that the user record is not deleted
            expect(User.find_by_id(user.id)).to be_present
          end
        end

        context 'when permissions are inherited from a complex ancestry' do
          let(:ldap_group1) { ldap_group_entry(user_dn(user.username)) }
          let(:group1) { create(:group) }
          let(:group2) { create(:group) }
          let(:group3) { create(:group) }

          before do
            group1.add_reporter(user)

            group2.update!(parent: group1)
            group2.add_maintainer(user)

            group3.update!(parent: group2)
            # no specific permission for user in group3

            group.update!(parent: group3)
          end

          it "applies the permission inherited from the closest ancestor when it's higher" do
            sync_group.update_permissions

            expect(group.members.find_by(user_id: user.id).access_level)
              .to eq(::Gitlab::Access::MAINTAINER)
          end
        end
      end

      include_examples 'inheritance from inherit_higher_access_levels'

      context 'when the extern_uid and group member DNs have different case' do
        let(:user1) { create(:user) }
        let(:user2) { create(:user) }

        # Change the case once on the LDAP group, and once on the GitLab Identity
        # to test that both sides can handle the differing case.
        let(:ldap_group1) do
          ldap_group_entry(%W[
            #{user_dn(user1.username).upcase}
            #{user_dn(user2.username)}
          ])
        end

        it 'does not revert the overrides' do
          create(:identity, user: user1, extern_uid: user_dn(user1.username))
          create(:identity, user: user2, extern_uid: user_dn(user2.username).upcase)
          group.members.create!(
            user: user1,
            access_level: ::Gitlab::Access::MAINTAINER,
            ldap: true,
            override: true
          )
          group.members.create!(
            user: user2,
            access_level: ::Gitlab::Access::OWNER,
            ldap: true,
            override: true
          )

          sync_group.update_permissions

          expect(group.members.pluck(:access_level))
            .to match_array([::Gitlab::Access::MAINTAINER, ::Gitlab::Access::OWNER])
        end

        it 'does not update permissions when group base is missing' do
          stub_ldap_config(group_base: nil)

          expect_any_instance_of(EE::Gitlab::Auth::Ldap::Sync::Proxy).not_to receive(:dns_for_group_cn)

          sync_group.update_permissions
        end
      end

      context 'when custom roles is enabled' do
        let(:member_role) { create(:member_role, :instance) }
        let(:ldap_group1) { ldap_group_entry(user_dn(user.username)) }

        before do
          stub_licensed_features(custom_roles: true)

          group.ldap_group_links.last.update!(member_role_id: member_role.id)
        end

        it 'assigns member role to synced ldap users' do
          sync_group.update_permissions

          member = group.members.find_by(user_id: user.id)

          expect(member.access_level).to eq(::Gitlab::Access::DEVELOPER)
          expect(member.member_role_id).to eq(member_role.id)
        end
      end
    end

    # Test that membership can be resolved for all different type of LDAP groups
    context 'with different LDAP group types' do
      # GroupOfNames - OpenLDAP
      context 'with groupOfNames style LDAP group' do
        let(:ldap_group1) do
          ldap_group_entry(
            user_dn(user.username),
            objectclass: 'groupOfNames',
            member_attr: 'uniqueMember'
          )
        end

        it 'adds the user to the group' do
          sync_group.update_permissions

          expect(group.members.pluck(:user_id)).to include(user.id)
        end
      end

      # posixGroup - Apple Open Directory
      context 'with posixGroup style LDAP group' do
        let(:ldap_group1) do
          ldap_group_entry(
            user.username,
            objectclass: 'posixGroup',
            member_attr: 'memberUid'
          )
        end

        let(:ldap_user) do
          ldap_user_entry(user.username)
        end

        it 'adds the user to the group' do
          stub_ldap_person_find_by_uid(user.username, ldap_user)

          sync_group.update_permissions

          expect(group.members.pluck(:user_id)).to include(user.id)
        end
      end

      context 'with groupOfUniqueNames style LDAP group' do
        let(:ldap_group1) do
          ldap_group_entry(
            user_dn(user.username),
            objectclass: 'groupOfUniqueNames',
            member_attr: 'uniqueMember'
          )
        end

        it 'adds the user to the group' do
          sync_group.update_permissions

          expect(group.members.pluck(:user_id)).to include(user.id)
        end
      end

      context 'with an empty LDAP group' do
        let(:ldap_group1) do
          ldap_group_entry(nil)
        end

        it 'does nothing, without failure' do
          expect { sync_group.update_permissions }
            .not_to change { group.members.count }
        end
      end
    end
  end

  context 'filter' do
    before do
      stub_licensed_features(ldap_group_sync_filter: true)
    end

    describe '#update_permissions' do
      let(:group) do
        create(:group_with_ldap_group_filter_link,
          group_access: ::Gitlab::Access::DEVELOPER)
      end

      let(:sync_group) { described_class.new(group, proxy(adapter)) }

      before do
        # Safe-check because some permissions are removed when `Group#ldap_synced?`
        # is true (e.g. in `GroupPolicy`).
        expect(group).to be_ldap_synced
        allow(sync_group.proxy).to receive(:dns_for_filter).and_return([user_dn(user.username)])

        group.start_ldap_sync
      end

      after do
        group.finish_ldap_sync
      end

      context 'with all functionality against one LDAP group type' do
        context 'with basic add/update actions' do
          let(:ldap_group1) { ldap_group_entry(user_dn(user.username)) }

          it 'does not update permissions unless ldap sync status is started' do
            group.finish_ldap_sync

            expect(Gitlab::AppLogger)
                .to receive(:warn).with(/status must be 'started' before updating permissions/)

            sync_group.update_permissions
          end

          it 'adds new members and sets ldap attribute to true' do
            sync_group.update_permissions

            expect(group).to have_user(user)
            expect(group.members.find_by(user_id: user.id).ldap?).to be_truthy
          end

          it 'updates permissions when group base is missing' do
            stub_ldap_config(group_base: nil)

            sync_group.update_permissions

            expect(group).to have_user(user)
          end
        end
      end
    end
  end
end
