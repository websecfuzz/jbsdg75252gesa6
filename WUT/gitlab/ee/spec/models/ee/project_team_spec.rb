# frozen_string_literal: true

require "spec_helper"

RSpec.describe ProjectTeam, feature_category: :groups_and_projects do
  describe '#import_team' do
    let_it_be(:source_project) { create(:project) }
    let_it_be(:target_project) { create(:project) }
    let_it_be(:source_project_developer) { create(:user) { |user| source_project.add_developer(user) } }
    let_it_be(:current_user) { create(:user) { |user| target_project.add_maintainer(user) } }

    subject(:import) { target_project.team.import(source_project, current_user) }

    it 'does not cause N+1 queries when checking user types' do
      control = ActiveRecord::QueryRecorder.new { target_project.team.import(source_project, current_user) }

      create(:user, :security_policy_bot) { |user| source_project.add_guest(user) }

      expect { import }.not_to exceed_query_limit(control)
    end

    context 'when a source project member is a security policy bot' do
      let_it_be(:source_project_security_policy_bot) do
        create(:user, :security_policy_bot) { |user| source_project.add_guest(user) }
      end

      it 'does not import the security policy bot user' do
        import

        expect(target_project.members.find_by(user: source_project_security_policy_bot)).to eq(nil)
      end
    end
  end

  describe '#add_member' do
    let_it_be(:group) { create(:group) }
    let(:project) { create(:project, group: group) }
    let(:user) { create(:user) }

    context 'when group membership is locked' do
      before do
        group.update_attribute(:membership_lock, true)
      end

      it 'does not add the given user to the team' do
        project.team.add_member(user, :reporter)

        expect(project.members.map(&:user)).not_to include(user)
      end

      context 'when user is a project bot' do
        let_it_be(:project_bot) { create(:user, :project_bot) }

        it 'adds the project bot user to the team' do
          project.team.add_member(project_bot, :maintainer)

          expect(project.members.map(&:user)).to include(project_bot)
        end
      end

      context 'when user is a security policy bot' do
        let_it_be(:security_policy_bot) { create(:user, :security_policy_bot) }

        it 'adds the project bot user to the team' do
          project.team.add_member(security_policy_bot, :maintainer)

          expect(project.members.map(&:user)).to include(security_policy_bot)
        end
      end
    end
  end

  describe '#members_with_access_level_or_custom_roles' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }

    let_it_be(:custom_role) { create(:member_role) }

    let_it_be(:developer) { create(:user) }
    let_it_be(:maintainer) { create(:user) }
    let_it_be(:reporter) { create(:user) }

    let_it_be(:levels) { [] }
    let_it_be(:member_role_ids) { [] }

    before do
      create(:project_member, :developer, project: project, user: developer, member_role: custom_role)
      create(:project_member, :maintainer, project: project, user: maintainer)
      create(:project_member, :reporter, project: project, user: reporter)
    end

    subject(:members_with_access_level_or_custom_roles) do
      project.team.members_with_access_level_or_custom_roles(levels: levels, member_role_ids: member_role_ids)
    end

    context 'when no parameters are provided' do
      it { is_expected.to be_empty }
    end

    context 'when filtering by access level' do
      let_it_be(:levels) { [Gitlab::Access::MAINTAINER] }

      it { is_expected.to contain_exactly(maintainer) }
    end

    context 'when filtering by custom roles' do
      let_it_be(:member_role_ids) { [custom_role.id] }

      it { is_expected.to contain_exactly(developer) }
    end

    context 'when filtering by both access level and custom roles' do
      let_it_be(:levels) { [Gitlab::Access::MAINTAINER] }
      let_it_be(:member_role_ids) { [custom_role.id] }

      it { is_expected.to contain_exactly(developer, maintainer) }
    end

    context 'when filtering with non-existent custom role' do
      let_it_be(:member_roles_id) { [non_existing_record_id] }

      it { is_expected.to be_empty }
    end
  end
end
