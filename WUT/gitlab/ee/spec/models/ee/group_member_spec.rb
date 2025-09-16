# frozen_string_literal: true
require 'spec_helper'

RSpec.describe GroupMember, feature_category: :groups_and_projects do
  it { is_expected.to include_module(EE::GroupMember) }

  it_behaves_like 'member validations'

  describe 'validations' do
    describe '#group_domain_validations' do
      let(:member_type) { :group_member }
      let(:source) { group }
      let(:nested_source) { create(:group, parent: group) }

      it_behaves_like 'member group domain validations', 'group'
    end

    describe 'access level inclusion' do
      let(:group) { create(:group) }

      context 'when minimal access user feature switched on' do
        before do
          stub_licensed_features(minimal_access_role: true)
        end

        it 'users can have access levels from minimal access to owner' do
          expect(build(:group_member, group: group, user: create(:user), access_level: ::Gitlab::Access::NO_ACCESS)).to be_invalid
          expect(build(:group_member, group: group, user: create(:user), access_level: ::Gitlab::Access::MINIMAL_ACCESS)).to be_valid
          expect(build(:group_member, group: group, user: create(:user), access_level: ::Gitlab::Access::GUEST)).to be_valid
          expect(build(:group_member, group: group, user: create(:user), access_level: ::Gitlab::Access::REPORTER)).to be_valid
          expect(build(:group_member, group: group, user: create(:user), access_level: ::Gitlab::Access::DEVELOPER)).to be_valid
          expect(build(:group_member, group: group, user: create(:user), access_level: ::Gitlab::Access::MAINTAINER)).to be_valid
          expect(build(:group_member, group: group, user: create(:user), access_level: ::Gitlab::Access::OWNER)).to be_valid
        end

        context 'when group is a subgroup' do
          let(:subgroup) { create(:group, parent: group) }

          it 'users cannot have minimal access level' do
            expect(build(:group_member, group: subgroup, user: create(:user), access_level: ::Gitlab::Access::MINIMAL_ACCESS)).to be_invalid
          end
        end
      end

      context 'when minimal access user feature switched off' do
        before do
          stub_licensed_features(minimal_access_role: false)
        end

        it 'users can have access levels from guest to owner' do
          expect(build(:group_member, group: group, user: create(:user), access_level: ::Gitlab::Access::NO_ACCESS)).to be_invalid
          expect(build(:group_member, group: group, user: create(:user), access_level: ::Gitlab::Access::MINIMAL_ACCESS)).to be_invalid
          expect(build(:group_member, group: group, user: create(:user), access_level: ::Gitlab::Access::GUEST)).to be_valid
          expect(build(:group_member, group: group, user: create(:user), access_level: ::Gitlab::Access::REPORTER)).to be_valid
          expect(build(:group_member, group: group, user: create(:user), access_level: ::Gitlab::Access::DEVELOPER)).to be_valid
          expect(build(:group_member, group: group, user: create(:user), access_level: ::Gitlab::Access::MAINTAINER)).to be_valid
          expect(build(:group_member, group: group, user: create(:user), access_level: ::Gitlab::Access::OWNER)).to be_valid
        end
      end
    end

    context 'with seat availability concerns', :saas do
      let_it_be(:group) { create(:group_with_plan, :private, plan: :free_plan) }

      before do
        stub_ee_application_setting(dashboard_limit_enabled: true)
      end

      context 'when seat is not available' do
        let_it_be(:user) { create(:user) }
        let!(:group_member) { build(:group_member, source: group, user: user) }

        context 'when ignore_user_limits is falsey' do
          it 'is invalid' do
            expect(group_member).to be_invalid
          end
        end

        context 'when ignore_user_limits is true' do
          before do
            group_member.ignore_user_limits = true
          end

          it 'is valid' do
            expect(group_member).to be_valid
          end
        end
      end
    end

    context 'when user is a security_policy_bot' do
      let_it_be(:group) { create(:group) }
      let_it_be(:bot_group_member) { build(:group_member, source: group, user: create(:user, :security_policy_bot)) }

      it 'is invalid' do
        expect(bot_group_member).to be_invalid
        expect(bot_group_member.errors[:member_user_type]).to include("Security policy bot cannot be added as a group member")
      end
    end
  end

  describe 'scopes' do
    let_it_be(:group) { create(:group) }
    let_it_be(:member1) { create(:group_member, group: group) }
    let_it_be(:member2) { create(:group_member, group: group) }
    let_it_be(:member3) { create(:group_member) }
    let_it_be(:guest1) { create(:group_member, :guest) }
    let_it_be(:guest2) { create(:group_member, :guest, group: group) }

    describe '.by_group_ids' do
      it 'returns only members from selected groups' do
        expect(described_class.by_group_ids([group.id])).to contain_exactly(member1, member2, guest2)
      end
    end

    describe '.guests' do
      it 'returns only guests members' do
        expect(described_class.guests).to contain_exactly(guest1, guest2)
      end
    end

    describe '.with_saml_identity' do
      let(:saml_provider) { create :saml_provider }
      let(:group) { saml_provider.group }
      let!(:member) do
        create(:group_member, group: group).tap do |m|
          create(:group_saml_identity, saml_provider: saml_provider, user: m.user)
        end
      end

      let!(:member_without_identity) do
        create(:group_member, group: group)
      end

      let!(:member_with_different_identity) do
        create(:group_member, group: group).tap do |m|
          create(:group_saml_identity, user: m.user)
        end
      end

      it 'returns members with identity linked to given saml provider' do
        expect(described_class.with_saml_identity(saml_provider)).to eq([member])
      end
    end

    describe '.eligible_approvers_by_groups' do
      let(:group) { create(:group) }
      let(:guest) { create(:user) }
      let(:developer) { create(:user) }
      let(:maintainer) { create(:user) }

      before do
        group.add_guest(guest)
        group.add_developer(developer)
        group.add_maintainer(maintainer)
      end

      subject(:approver_ids) do
        described_class
          .eligible_approvers_by_groups([group])
          .pluck_user_ids
      end

      it 'returns IDs of users with sufficient access level' do
        expect(approver_ids).to contain_exactly(developer.id, maintainer.id)
      end
    end
  end

  describe '.filter_by_enterprise_users' do
    let_it_be(:group) { create(:group) }
    let_it_be(:enterprise_user_member_1_of_group) { group.add_developer(create(:user, enterprise_group_id: group.id)) }
    let_it_be(:enterprise_user_member_2_of_group) { group.add_developer(create(:user, enterprise_group_id: group.id)) }
    let_it_be(:non_enterprise_user_member_of_group) { group.add_developer(create(:user)) }

    it 'returns members that are enterprise users of a group when the filter is `true`' do
      result = described_class.filter_by_enterprise_users(true)

      expect(result.to_a).to match_array([enterprise_user_member_1_of_group, enterprise_user_member_2_of_group])
    end

    it 'returns members that are not enterprise users of a group when the filter is `false`' do
      result = described_class.filter_by_enterprise_users(false)

      expect(result.to_a).to match_array([non_enterprise_user_member_of_group])
    end
  end

  context 'refreshing project_authorizations' do
    let_it_be_with_refind(:group) { create(:group) }
    let_it_be_with_refind(:user) { create(:user) }
    let_it_be(:group_member) { create(:group_member, :guest, group: group, user: user) }
    let_it_be(:project) { create(:project, namespace: group) }

    context 'when the source group of the group member is destroyed' do
      it 'refreshes the authorization of user to the project in the group' do
        expect { group.destroy! }.to change { user.can?(:guest_access, project) }.from(true).to(false)
      end

      it 'refreshes the authorization without calling UserProjectAccessChangedService' do
        expect(UserProjectAccessChangedService).not_to receive(:new)

        group.destroy!
      end
    end

    context 'when the user of the group member is destroyed' do
      it 'refreshes the authorization of user to the project in the group' do
        expect(project.authorized_users).to include(user)

        user.destroy!

        expect(project.authorized_users).not_to include(user)
      end

      it 'refreshes the authorization without calling UserProjectAccessChangedService' do
        expect(UserProjectAccessChangedService).not_to receive(:new)

        user.destroy!
      end
    end
  end

  describe '#state' do
    let!(:group) { create(:group) }
    let!(:project) { create(:project, group: group) }
    let!(:user) { create(:user) }

    describe '#activate!' do
      it "refreshes the user's authorized projects" do
        membership = create(:group_member, :awaiting, source: group, user: user)

        expect(user.authorized_projects).not_to include(project)

        membership.activate!

        expect(user.authorized_projects.reload).to include(project)
      end
    end

    describe '#wait!' do
      # the last owner can't be set to awaiting
      let!(:owner) { create(:group_member, :owner, group: group) }

      it "refreshes the user's authorized projects" do
        membership = create(:group_member, source: group, user: user)

        expect(user.authorized_projects).to include(project)

        membership.wait!

        expect(user.authorized_projects.reload).not_to include(project)
      end
    end
  end

  context 'group member webhooks', :sidekiq_inline, :saas do
    let_it_be_with_refind(:group) { create(:group_with_plan, plan: :ultimate_plan) }
    let_it_be(:group_hook) { create(:group_hook, group: group, member_events: true) }
    let_it_be(:user) { create(:user) }

    context 'when the group member is deleted' do
      let_it_be(:group_member) { create(:group_member, :developer, group: group, expires_at: 1.day.from_now) }

      it 'executes user_remove_from_group event webhook when group member is deleted' do
        WebMock.stub_request(:post, group_hook.url)

        group_member.destroy!

        expect(WebMock).to have_requested(:post, group_hook.url).with(
          webhook_data(group_member, 'user_remove_from_group')
        )
      end
    end

    context 'when user requested access' do
      it 'executes user_access_request_to_group event webhook when group member is created' do
        WebMock.stub_request(:post, group_hook.url)

        group_member = create(:group_member, group: group, requested_at: Time.current.utc)

        expect(WebMock).to have_requested(:post, group_hook.url).with(
          webhook_data(group_member, 'user_access_request_to_group')
        )
      end

      it 'executes user_access_request_revoked_for_group event webhook when access request is revoked' do
        WebMock.stub_request(:post, group_hook.url)
        group_member = create(:group_member, group: group, requested_at: Time.current.utc)

        group_member.destroy!

        expect(WebMock).to have_requested(:post, group_hook.url).with(
          webhook_data(group_member, 'user_access_request_revoked_for_group')
        )
      end
    end

    context 'does not execute webhook' do
      before do
        WebMock.stub_request(:post, group_hook.url)
      end

      it 'does not execute webhooks if group member events webhook is disabled' do
        group_hook = create(:group_hook, group: group, member_events: false)

        group.add_guest(user)

        expect(WebMock).not_to have_requested(:post, group_hook.url)
      end

      it 'does not execute webhooks if license is disabled' do
        stub_licensed_features(group_webhooks: false)

        group.add_guest(user)

        expect(WebMock).not_to have_requested(:post, group_hook.url)
      end
    end
  end

  describe '#provisioned_by_this_group?' do
    let_it_be(:group) { create(:group) }

    let(:user) { build(:user) }
    let(:member) { build(:group_member, group: group, user: user) }
    let(:invited) { build(:group_member, :invited, group: group, user: user) }

    subject { member.provisioned_by_this_group? }

    context 'when user is provisioned by the group' do
      let(:user) { build(:user, provisioned_by_group_id: group.id) }

      it { is_expected.to eq(true) }
    end

    context 'when user is not provisioned by the group' do
      it { is_expected.to eq(false) }
    end

    context 'when member does not have a related user (invited member)' do
      let(:member) { invited }

      it { is_expected.to eq(false) }
    end
  end

  describe 'enterprise_user_of_this_group?' do
    let_it_be(:group) { create(:group) }

    let(:user) { build(:user) }
    let(:member) { build(:group_member, group: group, user: user) }
    let(:invited) { build(:group_member, :invited, group: group) }

    subject { member.enterprise_user_of_this_group? }

    context 'when member is an enterprise user of this group' do
      let!(:user_detail) { build(:user_detail, user: user, enterprise_group_id: group.id) }

      it { is_expected.to eq(true) }
    end

    context 'when member is not an enterprise user of this group' do
      it { is_expected.to eq(false) }
    end

    context 'when member does not have a related user (invited member)' do
      let(:member) { invited }

      it { is_expected.to eq(false) }
    end
  end

  describe '#prevent_role_assignement?' do
    let_it_be(:group) { create(:group) }
    let_it_be_with_reload(:current_user) { create(:user) }
    let_it_be_with_reload(:member) do
      create(:group_member, access_level: Gitlab::Access::GUEST, group: group)
    end

    let(:member_role_id) { nil }
    let(:access_level) { Gitlab::Access::GUEST }
    let(:params) { { member_role_id: member_role_id, access_level: access_level } }

    subject(:prevent_assignement?) { member.prevent_role_assignement?(current_user, params) }

    context 'for custom roles assignement' do
      let_it_be(:member_role_current_user) do
        create(:member_role, :maintainer, admin_group_member: true, admin_merge_request: true)
      end

      let_it_be(:member_role_less_abilities) do
        create(:member_role, :guest, admin_merge_request: true)
      end

      let_it_be(:member_role_more_abilities) do
        create(:member_role, :guest, admin_merge_request: true, read_code: true)
      end

      before do
        current_member = group.add_maintainer(current_user)
        current_member.update!(member_role: member_role_current_user)
      end

      context 'with the same custom role as current user has' do
        let(:member_role_id) { member_role_current_user.id }

        it 'returns false' do
          expect(prevent_assignement?).to eq(false)
        end
      end

      context 'with the custom role having less abilities than current user has' do
        let(:member_role_id) { member_role_less_abilities.id }

        it 'returns false' do
          expect(prevent_assignement?).to eq(false)
        end
      end

      context 'with the custom role having more abilities than current user has' do
        let(:member_role_id) { member_role_more_abilities.id }

        context 'when current user is a MAINTAINER' do
          it 'returns true' do
            expect(prevent_assignement?).to eq(true)
          end
        end

        context 'when current user is an admin', :enable_admin_mode do
          before do
            current_user.members.delete_all

            current_user.update!(admin: true)
          end

          it 'returns false' do
            expect(prevent_assignement?).to eq(false)
          end
        end
      end
    end

    context 'for default access roles' do
      let(:member_role_id) { nil }

      context 'when current user is a DEVELOPER' do
        before do
          group.add_developer(current_user)
        end

        context 'without assigning_access_level param' do
          let(:access_level) { nil }

          it 'returns false' do
            expect(prevent_assignement?).to eq(false)
          end
        end

        context 'with MAINTAINER as access_role param' do
          let(:access_level) { Gitlab::Access::MAINTAINER }

          it 'returns true' do
            expect(prevent_assignement?).to eq(true)
          end
        end
      end

      context 'when current user is a MAINTAINER' do
        before do
          group.add_maintainer(current_user)
        end

        context 'without assigning_access_level param' do
          let(:access_level) { nil }

          it 'returns true' do
            expect(prevent_assignement?).to eq(false)
          end
        end

        context 'with OWNER as access_role param' do
          let(:access_level) { Gitlab::Access::OWNER }

          it 'returns false' do
            expect(prevent_assignement?).to eq(true)
          end
        end
      end

      context 'when current user is an admin', :enable_admin_mode do
        before do
          current_user.update!(admin: true)
        end

        context 'without assigning_access_level param' do
          let(:access_level) { nil }

          it 'returns false' do
            expect(prevent_assignement?).to eq(false)
          end
        end

        context 'with OWNER as access_role param' do
          let(:access_level) { Gitlab::Access::OWNER }

          it 'returns false' do
            expect(prevent_assignement?).to eq(false)
          end
        end
      end
    end
  end

  def webhook_data(group_member, event)
    {
      headers: { 'Content-Type' => 'application/json', 'User-Agent' => "GitLab/#{Gitlab::VERSION}", 'X-Gitlab-Event' => 'Member Hook' },
      body: {
        created_at: group_member.created_at&.xmlschema,
        updated_at: group_member.updated_at&.xmlschema,
        group_name: group.name,
        group_path: group.path,
        group_id: group.id,
        user_username: group_member.user.username,
        user_name: group_member.user.name,
        user_email: group_member.user.webhook_email,
        user_id: group_member.user.id,
        group_access: group_member.human_access,
        expires_at: group_member.expires_at&.xmlschema,
        group_plan: 'ultimate',
        event_name: event
      }.to_json
    }
  end
end
