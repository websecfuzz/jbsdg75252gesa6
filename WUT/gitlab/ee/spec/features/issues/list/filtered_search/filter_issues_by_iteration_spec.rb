# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Filter issues by iteration', :js, feature_category: :team_planning do
  include FilteredSearchHelpers
  include Features::IterationHelpers

  let_it_be(:group) { create(:group, :public) }
  let_it_be(:project) { create(:project, :public, group: group) }

  let_it_be(:cadence_1) { create(:iterations_cadence, group: group) }
  let_it_be(:cadence_2) { create(:iterations_cadence, group: group) }

  let_it_be(:iteration_1) { create(:iteration, iterations_cadence: cadence_1, start_date: Date.today) }
  let_it_be(:iteration_2) { create(:iteration, iterations_cadence: cadence_2) }
  let_it_be(:iteration_3) { create(:iteration, iterations_cadence: cadence_1) }

  let_it_be(:iteration_1_issue) { create(:issue, project: project, iteration: iteration_1) }
  let_it_be(:iteration_2_issue) { create(:issue, project: project, iteration: iteration_2) }
  let_it_be(:no_iteration_issue) { create(:issue, project: project) }

  before do
    # TODO: When removing the feature flag,
    # we won't need the tests for the issues listing page, since we'll be using
    # the work items listing page.
    stub_feature_flags(work_item_planning_view: false)
  end

  shared_examples 'filters by iteration' do
    context 'when iterations are not available' do
      before do
        stub_licensed_features(iterations: false)

        visit page_path
      end

      it 'does not show the iteration filter option' do
        click_filtered_search_bar

        expect_no_suggestion 'Iteration'
      end
    end

    context 'when iterations are available' do
      before do
        stub_licensed_features(iterations: true)

        visit page_path

        page.has_content?(iteration_1_issue.title)
        page.has_content?(iteration_2_issue.title)
        page.has_content?(no_iteration_issue.title)
      end

      shared_examples 'filters issues by iteration' do
        it 'filters correct issues' do
          aggregate_failures do
            expect(page).to have_content(iteration_1_issue.title)
            expect(page).not_to have_content(iteration_2_issue.title)
            expect(page).not_to have_content(no_iteration_issue.title)
          end
        end
      end

      shared_examples 'filters issues by negated iteration' do
        it 'filters by negated iteration' do
          aggregate_failures do
            expect(page).not_to have_content(iteration_1_issue.title)
            expect(page).to have_content(iteration_2_issue.title)
            expect(page).to have_content(no_iteration_issue.title)
          end
        end
      end

      context 'when passing specific iteration by period' do
        before do
          select_tokens 'Iteration', '=', iteration_period(iteration_1), submit: true
        end

        it_behaves_like 'filters issues by iteration'
      end

      context 'when passing Current iteration' do
        before do
          select_tokens 'Iteration', '=', 'Current', submit: true
        end

        it_behaves_like 'filters issues by iteration'
      end

      context 'when filtering by negated iteration' do
        before do
          visit page_path

          select_tokens 'Iteration', '!=', iteration_item, submit: true
        end

        context 'with specific iteration' do
          let(:iteration_item) { iteration_period(iteration_1) }

          it_behaves_like 'filters issues by negated iteration'
        end

        context 'with current iteration' do
          let(:iteration_item) { 'Current' }

          it_behaves_like 'filters issues by negated iteration'
        end
      end
    end
  end

  shared_examples 'shows iterations when using iteration token' do
    context 'when viewing list of iterations' do
      before do
        visit page_path

        select_tokens 'Iteration', '='
      end

      it 'shows cadence titles, and iteration periods and dates', :aggregate_failures do
        within '.gl-filtered-search-suggestion-list' do
          # cadence 1 grouping
          expect(page).to have_css('li:nth-child(6)', text: 'Any')
          expect(page).to have_css('li:nth-child(7)', text: 'Current')
          expect(page).to have_css('li:nth-child(8)', text: iteration_period(iteration_3, use_thin_space: false))
          expect(page).to have_css('li:nth-child(9)', text: iteration_period(iteration_1, use_thin_space: false))
          # cadence 2 grouping
          expect(page).to have_css('li:nth-child(11)', text: cadence_2.title)
          expect(page).to have_css('li:nth-child(12)', text: 'Any')
          expect(page).to have_css('li:nth-child(13)', text: 'Current')
          expect(page).to have_css('li:nth-child(14)', text: iteration_period(iteration_2, use_thin_space: false))
        end
      end
    end
  end

  context 'project issues list' do
    let(:page_path) { project_issues_path(project) }
    let(:issue_title_selector) { '.issue .title' }

    it_behaves_like 'filters by iteration'

    it_behaves_like 'shows iterations when using iteration token'
  end

  context 'group issues list' do
    let(:page_path) { issues_group_path(group) }
    let(:issue_title_selector) { '.issue .title' }

    it_behaves_like 'filters by iteration'

    it_behaves_like 'shows iterations when using iteration token'
  end

  context 'project board' do
    let_it_be(:board) { create(:board, project: project) }

    let(:page_path) { project_board_path(project, board) }
    let(:issue_title_selector) { '.board-card .board-card-title' }

    it_behaves_like 'filters by iteration'
  end

  context 'group board' do
    let_it_be(:board) { create(:board, group: group) }
    let_it_be(:user) { create(:user) }

    let(:page_path) { group_board_path(group, board) }
    let(:issue_title_selector) { '.board-card .board-card-title' }

    before_all do
      group.add_developer(user)
    end

    before do
      sign_in user
    end

    it_behaves_like 'filters by iteration'
  end
end
