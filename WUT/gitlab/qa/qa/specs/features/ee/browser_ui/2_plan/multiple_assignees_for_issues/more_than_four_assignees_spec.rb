# frozen_string_literal: true

module QA
  RSpec.describe 'Plan', :requires_admin, product_group: :project_management do
    describe 'Multiple assignees per issue' do
      let(:project) { create(:project, name: 'project-to-test-issue-with-multiple-assignees') }

      before do
        Flow::Login.sign_in

        user_1 = create(:user)
        user_2 = create(:user)
        user_3 = create(:user)
        user_4 = create(:user)
        user_5 = create(:user)
        user_6 = create(:user)

        project.add_member(user_1)
        project.add_member(user_2)
        project.add_member(user_3)
        project.add_member(user_4)
        project.add_member(user_5)
        project.add_member(user_6)

        @issue = create(:issue,
          project: project,
          assignee_ids: [
            user_1.id,
            user_2.id,
            user_3.id,
            user_4.id,
            user_5.id,
            user_6.id
          ])
      end

      it 'shows the first three assignees and a +n sign in the issues list', testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347976' do
        project.visit!

        Page::Project::Menu.perform(&:go_to_work_items)

        page_type = Page::Project::Issue::Index

        page_type.perform do |index|
          expect(index).to have_assignee_link_count(3)
          expect(index.avatar_counter).to be_visible
          expect(index.avatar_counter).to have_content('+3')
        end
      end

      it 'shows the first five assignees and a +n more link in the issue page', testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347977' do
        @issue.visit!

        work_item_enabled = Page::Project::Issue::Show.perform(&:work_item_enabled?)
        page_type = work_item_enabled ? Page::Project::WorkItem::Show : Page::Project::Issue::Show

        page_type.perform do |show|
          expect(show).to have_avatar_image_count(5)
          expect(show.more_assignees_link).to be_visible
          expect(show.more_assignees_link).to have_content('+ 1 more')

          show.toggle_more_assignees_link

          expect(show).to have_avatar_image_count(6)
          expect(show.more_assignees_link).to have_content('- show less')
        end
      end
    end
  end
end
