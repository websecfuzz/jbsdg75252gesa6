# frozen_string_literal: true
require 'spec_helper'

RSpec.describe ProjectMember, feature_category: :groups_and_projects do
  it { is_expected.to include_module(EE::ProjectMember) }

  it_behaves_like 'member validations' do
    let(:entity) { create(:project, group: group) }
  end

  context 'validates GMA enforcement' do
    let(:group) { create(:group_with_managed_accounts, :private) }
    let(:entity) { create(:project, namespace: group) }

    before do
      stub_feature_flags(group_managed_accounts: true)
    end

    context 'enforced group managed account enabled' do
      before do
        stub_licensed_features(group_saml: true)
      end

      it 'allows adding a user linked to the GMA account as project member' do
        user = create(:user, :group_managed, managing_group: group)
        member = entity.add_developer(user)

        expect(member).to be_valid
      end

      it 'does not allow adding a user not linked to the GMA account as project member' do
        member = entity.add_developer(create(:user))

        expect(member).not_to be_valid
        expect(member.errors.messages[:user]).to include('is not in the group enforcing Group Managed Account')
      end

      it 'allows adding a project bot' do
        member = entity.add_developer(create(:user, :project_bot))

        expect(member).to be_valid
      end
    end

    context 'enforced group managed account disabled' do
      it 'allows adding any user as project member' do
        member = entity.add_developer(create(:user))

        expect(member).to be_valid
      end
    end
  end

  describe '#group_domain_validations' do
    let(:member_type) { :project_member }
    let(:source) { create(:project, namespace: group) }
    let(:subgroup) { create(:group, parent: group) }
    let(:nested_source) { create(:project, namespace: subgroup) }

    it_behaves_like 'member group domain validations', 'project'

    it 'does not validate personal projects' do
      unconfirmed_gitlab_user = create(:user, :unconfirmed, email: 'unverified@gitlab.com')
      member = create(:project, namespace: create(:user).namespace).add_developer(unconfirmed_gitlab_user)

      expect(member).to be_valid
    end
  end

  describe 'security policy project bot validation' do
    let_it_be(:project) { create(:project) }
    let_it_be(:security_policy_bot) { create(:user, :security_policy_bot) }

    it 'allows to be added to project' do
      member = project.add_guest(security_policy_bot)

      expect(member).to be_valid
    end
  end

  describe 'only one security policy bot validation' do
    let_it_be(:user1) { create(:user, :security_policy_bot) }
    let_it_be(:user2) { create(:user, :security_policy_bot) }
    let_it_be(:user3) { create(:user) }
    let_it_be(:project) { create(:project) }

    it 'allows only one member of type security_policy_bot' do
      expect { create(:project_member, user: user1, project: project) }.not_to raise_error
      expect { create(:project_member, user: user2, project: project) }.to raise_error(ActiveRecord::RecordInvalid)
      expect { create(:project_member, user: user3, project: project) }.not_to raise_error
    end

    it 'does not throw an error if user is nil' do
      expect { create(:project_member, :invited) }.not_to raise_error
    end
  end

  describe '#provisioned_by_this_group?' do
    let_it_be(:member) { build(:project_member) }

    subject { member.provisioned_by_this_group? }

    it { is_expected.to eq(false) }
  end

  describe '#enterprise_user_of_this_group?' do
    let_it_be(:member) { build(:project_member) }

    subject { member.enterprise_user_of_this_group? }

    it { is_expected.to eq(false) }
  end

  describe '#state' do
    let!(:group) { create(:group) }
    let!(:project) { create(:project, group: group) }
    let!(:user) { create(:user) }

    describe '#activate!' do
      it "refreshes the user's authorized projects" do
        membership = create(:project_member, :awaiting, source: project, user: user)

        expect(user.authorized_projects).not_to include(project)

        membership.activate!

        expect(user.authorized_projects.reload).to include(project)
      end
    end

    describe '#wait!' do
      it "refreshes the user's authorized projects" do
        membership = create(:project_member, source: project, user: user)

        expect(user.authorized_projects).to include(project)

        membership.wait!

        expect(user.authorized_projects.reload).not_to include(project)
      end
    end
  end

  describe 'delete protected environment acceses cascadingly' do
    let_it_be(:project) { create(:project) }
    let_it_be(:user) { create(:user) }
    let_it_be(:environment) { create(:environment, project: project) }
    let_it_be(:protected_environment) do
      create(:protected_environment, project: project, name: environment.name)
    end

    let!(:member) { create(:project_member, project: project, user: user) }

    let!(:deploy_access) do
      create(:protected_environment_deploy_access_level, protected_environment: protected_environment, user: user)
    end

    let!(:deploy_access_for_diffent_user) do
      create(:protected_environment_deploy_access_level, protected_environment: protected_environment, user: create(:user))
    end

    let!(:deploy_access_for_group) do
      create(:protected_environment_deploy_access_level, protected_environment: protected_environment, group: create(:group))
    end

    let!(:deploy_access_for_maintainer_role) do
      create(:protected_environment_deploy_access_level, :maintainer_access, protected_environment: protected_environment)
    end

    it 'deletes associated protected environment access cascadingly' do
      expect { member.destroy! }
        .to change { ProtectedEnvironments::DeployAccessLevel.count }.by(-1)

      expect { deploy_access.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect(protected_environment.reload.deploy_access_levels)
        .to include(deploy_access_for_diffent_user, deploy_access_for_group, deploy_access_for_maintainer_role)
    end

    context 'when the user is assiged to multiple protected environments in the same project' do
      let!(:other_protected_environment) { create(:protected_environment, project: project, name: 'staging') }
      let!(:other_deploy_access) { create(:protected_environment_deploy_access_level, protected_environment: other_protected_environment, user: user) }

      it 'deletes all associated protected environment accesses in the project' do
        expect { member.destroy! }
          .to change { ProtectedEnvironments::DeployAccessLevel.count }.by(-2)

        expect { deploy_access.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect { other_deploy_access.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when the user is assiged to multiple protected environments across different projects' do
      let!(:other_project) { create(:project) }
      let!(:other_protected_environment) { create(:protected_environment, project: other_project, name: 'staging') }
      let!(:other_deploy_access) { create(:protected_environment_deploy_access_level, protected_environment: other_protected_environment, user: user) }

      it 'deletes all associated protected environment accesses in the project' do
        expect { member.destroy! }
          .to change { ProtectedEnvironments::DeployAccessLevel.count }.by(-1)

        expect { deploy_access.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect { other_deploy_access.reload }.not_to raise_error
      end
    end
  end

  describe 'deletes member branch access rules cascadingly' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:user) { create(:user) }
    let_it_be(:protected_branches) { create_list(:protected_branch, 2, project: project) }

    let!(:member) { create(:project_member, project: project, user: user) }

    it 'deletes all associated merge_access_levels in the project' do
      protected_branches.each do |protected_branch|
        protected_branch.merge_access_levels.create!(user: user)
      end

      expect { member.destroy! }
        .to change { ProtectedBranch::MergeAccessLevel.count }.by(-2)
    end

    it 'deletes all associated push_access_levels in the project' do
      protected_branches.each do |protected_branch|
        protected_branch.push_access_levels.create!(user: user)
      end

      expect { member.destroy! }
        .to change { ProtectedBranch::PushAccessLevel.count }.by(-2)
    end

    context 'when user still has inherited access to the project' do
      let!(:inherited_membership) { group.add_guest(user) }

      it 'does not delete associated merge_access_levels in the project' do
        protected_branches.each do |protected_branch|
          protected_branch.merge_access_levels.create!(user: user)
        end

        expect { member.destroy! }
          .not_to change { ProtectedBranch::MergeAccessLevel.count }
      end

      it 'does not delete associated push_access_levels in the project' do
        protected_branches.each do |protected_branch|
          protected_branch.push_access_levels.create!(user: user)
        end

        expect { member.destroy! }
          .not_to change { ProtectedBranch::PushAccessLevel.count }
      end
    end
  end

  describe '#accept_invite!' do
    let(:member) { create(:project_member, :invited) }
    let(:user) { create(:user) }

    it 'does not accept invite if group locks memberships for projects' do
      expect(member).to receive_message_chain(:source, :membership_locked?).and_return(true)

      member.accept_invite! user

      expect(member.user).to be_nil
      expect(member.invite_accepted_at).to be_nil
      expect(member.invite_token).not_to be_nil
      expect(member).not_to receive(:after_accept_invite)
    end
  end
end
