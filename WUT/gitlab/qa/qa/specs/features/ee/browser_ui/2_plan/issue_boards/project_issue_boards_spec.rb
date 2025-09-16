# frozen_string_literal: true

module QA
  RSpec.describe 'Plan', product_group: :project_management do
    describe 'Project issue boards' do
      before do
        Flow::Login.sign_in
      end

      let(:issue_title) { 'Issue to test board list' }

      context 'Label issue board' do
        let(:label) { 'Testing' }

        let(:label_board_list) do
          EE::Resource::Board::BoardList::Project::LabelBoardList.fabricate_via_api!
        end

        before do
          create(:issue, project: label_board_list.project, title: issue_title, labels: [label])

          go_to_project_board(label_board_list.project)
        end

        it 'shows the just created board with a "Testing" (label) list, and an issue on it',
          testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347990' do
          Page::Component::IssueBoard::Show.perform do |show|
            expect(show.boards_dropdown).to have_content(label_board_list.board.name)
            expect(show.boards_list_header_with_index(1)).to have_content(label)
            expect(show.card_of_list_with_index(1)).to have_content(issue_title)
          end
        end
      end

      context 'Milestone issue board' do
        let(:milestone_board_list) do
          EE::Resource::Board::BoardList::Project::MilestoneBoardList.fabricate_via_api!
        end

        before do
          create(:issue, project: milestone_board_list.project, title: issue_title,
            milestone: milestone_board_list.project_milestone)

          go_to_project_board(milestone_board_list.project)
        end

        it 'shows the just created board with a "1.0" (milestone) list, and an issue on it',
          testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347953' do
          Page::Component::IssueBoard::Show.perform do |show|
            expect(show.boards_dropdown).to have_content(milestone_board_list.board.name)
            expect(show.boards_list_header_with_index(1)).to have_content('1.0')
            expect(show.card_of_list_with_index(1)).to have_content(issue_title)
          end
        end
      end

      context 'Assignee issue board' do
        let(:user) { Runtime::User::Store.additional_test_user }
        let(:project) { create(:project, name: 'project-to-test-assignee-issue-board-list') }

        let(:assignee_board_list) do
          EE::Resource::Board::BoardList::Project::AssigneeBoardList.fabricate_via_api! do |board_list|
            board_list.assignee = user
            board_list.project = project
          end
        end

        before do
          project.add_member(user)

          create(:issue, assignee_ids: user.id, project: project, title: issue_title)

          assignee_board_list # create the board list

          go_to_project_board(project)
        end

        it 'shows the just created board with an assignee list, and an issue on it',
          testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347991' do
          Page::Component::IssueBoard::Show.perform do |show|
            expect(show.boards_dropdown).to have_content(assignee_board_list.board.name)
            expect(show.boards_list_header_with_index(1)).to have_content(user.name)
            expect(show.card_of_list_with_index(1)).to have_content(issue_title)
          end
        end
      end

      private

      def go_to_project_board(project)
        project.visit!
        Page::Project::Menu.perform(&:go_to_issue_boards)
      end
    end
  end
end
