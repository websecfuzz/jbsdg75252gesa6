# frozen_string_literal: true

module QA
  RSpec.describe 'Plan', :smoke, :requires_admin, product_group: :project_management do
    describe 'Multiple assignees per issue' do
      before do
        Flow::Login.sign_in

        user_1 = create(:user)
        user_2 = create(:user)
        user_3 = create(:user)
        user_4 = create(:user)

        project = create(:project, name: 'project-to-test-issue-with-multiple-assignees')
        project.add_member(user_1)
        project.add_member(user_2)
        project.add_member(user_3)
        project.add_member(user_4)

        create(:issue,
          project: project,
          assignee_ids: [
            user_1.id,
            user_2.id,
            user_3.id,
            user_4.id
          ])

        project.visit!
      end

      it 'shows four assignees in the issues list', testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347960' do
        Page::Project::Menu.perform(&:go_to_work_items)

        Page::Project::Issue::Index.perform do |index|
          expect(index).to have_assignee_link_count(4)
        end
      end
    end
  end
end
