# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User adds milestone/iterations lists', :js, :aggregate_failures, feature_category: :team_planning do
  include Features::IterationHelpers

  let_it_be(:group) { create(:group, :nested) }
  let_it_be(:project) { create(:project, :public, namespace: group) }
  let_it_be(:group_board) { create(:board, group: group) }
  let_it_be(:project_board) { create(:board, project: project) }
  let_it_be(:user) { create(:user, maintainer_of: project, owner_of: group) }

  let_it_be(:milestone) { create(:milestone, group: group) }
  let_it_be(:iteration) { create(:iteration, iterations_cadence: create(:iterations_cadence, group: group)) }

  let_it_be(:issue_with_milestone) { create(:issue, project: project, milestone: milestone) }
  let_it_be(:issue_with_assignee) { create(:issue, project: project, assignees: [user]) }
  let_it_be(:issue_with_iteration) { create(:issue, project: project, iteration: iteration) }

  where(:board_type) do
    [[:project], [:group]]
  end

  with_them do
    before do
      stub_licensed_features(
        board_milestone_lists: true,
        board_assignee_lists: true,
        board_iteration_lists: true
      )
      sign_in(user)

      case board_type
      when :project
        visit project_board_path(project, project_board)
      when :group
        visit group_board_path(group, group_board)
      end

      wait_for_all_requests
    end

    it 'creates milestone column' do
      add_list('Milestone', milestone.title)

      expect(page).to have_selector('.board', text: milestone.title)
      expect(find('[data-testid="board-list"]:nth-child(2) .board-card')).to have_content(issue_with_milestone.title)
    end

    it 'creates assignee column' do
      add_list('Assignee', user.name)

      expect(page).to have_selector('.board', text: user.name)
      expect(find('[data-testid="board-list"]:nth-child(2) .board-card')).to have_content(issue_with_assignee.title)
    end

    it 'creates iteration column' do
      add_list('Iteration', iteration_period(iteration, use_thin_space: false))

      expect(page).to have_selector('.board', text: iteration.display_text)
      expect(find('[data-testid="board-list"]:nth-child(2) .board-card')).to have_content(issue_with_iteration.title)
    end
  end

  describe 'without a license' do
    before do
      stub_licensed_features(
        board_milestone_lists: false,
        board_assignee_lists: false,
        board_iteration_lists: false
      )

      sign_in(user)

      visit project_board_path(project, project_board)

      wait_for_all_requests
    end

    it 'does not show other list types', :aggregate_failures do
      click_button 'New list'
      wait_for_all_requests

      within_testid('board-add-new-column') do
        expect(page).not_to have_text('Iteration')
        expect(page).not_to have_text('Assignee')
        expect(page).not_to have_text('Milestone')
      end
    end
  end

  def add_list(list_type, title)
    click_button 'New list'
    wait_for_all_requests

    page.choose(list_type)

    find_button("Select a").click

    within_testid('base-dropdown-menu') do
      find('label', text: title).click
    end

    click_button 'Add to board'

    wait_for_all_requests
  end
end
