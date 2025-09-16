# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Issue Sidebar', :js, feature_category: :team_planning do
  include ListboxHelpers
  include MobileHelpers
  include Features::IterationHelpers

  # Ensure support bot user is created so creation doesn't count towards query limit
  # See https://gitlab.com/gitlab-org/gitlab/-/issues/509629
  let_it_be(:support_bot) { Users::Internal.support_bot }

  let_it_be(:group) { create(:group, :nested) }
  let_it_be(:project) { create(:project, :public, namespace: group) }
  let_it_be(:project_without_group) { create(:project, :public) }
  let_it_be(:user) { create(:user) }
  let_it_be(:label) { create(:label, project: project, title: 'bug') }
  let_it_be(:issue) { create(:labeled_issue, project: project, labels: [label]) }
  let_it_be(:issue_no_group) { create(:labeled_issue, project: project_without_group, labels: [label]) }

  before do
    stub_feature_flags(work_item_view_for_issues: true)
    sign_in(user)
  end

  context 'for accessibility' do
    it 'passes axe automated accessibility testing' do
      project.add_developer(user)
      visit_issue(project, issue)

      expect(page).to be_axe_clean.within('section.work-item-overview-right-sidebar')
    end
  end

  describe 'weight' do
    context 'when updating weight' do
      before do
        project.add_maintainer(user)
        visit_issue(project, issue)
      end

      it 'updates weight in sidebar to 0 and updates to no weight by clicking "Remove weight" button' do
        within_testid('work-item-weight') do
          click_button 'Edit'
          send_keys 0, :enter

          expect(page).to have_text '0'

          click_button 'Edit'
          click_button 'Remove weight'

          expect(page).to have_text 'None'
        end
      end

      it 'updates weight in sidebar to no weight by setting an empty value' do
        within_testid('work-item-weight') do
          click_button 'Edit'
          send_keys 1, :enter

          expect(page).to have_text '1'

          click_button 'Edit'
          send_keys :backspace, :enter

          expect(page).to have_text 'None'
        end
      end
    end

    context 'as a guest' do
      before do
        project.add_guest(user)
        visit_issue(project, issue)
      end

      it 'does not have a option to edit weight' do
        within_testid('work-item-weight') do
          expect(page).not_to have_button('Edit')
        end
      end
    end
  end

  describe 'health status' do
    before do
      project.add_developer(user)
    end

    context 'when health status feature is available' do
      before do
        stub_licensed_features(issuable_health_status: true)
        visit_issue(project, issue)
      end

      it 'updates health status on sidebar' do
        within_testid('work-item-health-status') do
          click_button 'Edit'
          select_listbox_item 'On track'

          expect(page).to have_text 'On track'
        end
      end

      context 'when user closes an issue' do
        it 'disables the edit button' do
          click_button 'More actions', match: :first
          click_button 'Close issue', match: :first

          within_testid('work-item-health-status') do
            expect(page).not_to have_button('Edit')
          end
        end
      end
    end

    context 'when health status feature is not available' do
      it 'does not show health status on sidebar' do
        stub_licensed_features(issuable_health_status: false)
        visit_issue(project, issue)

        expect(page).not_to have_css('[data-testid="work-item-health-status"]')
      end
    end
  end

  describe 'iterations' do
    context 'when iterations feature available' do
      let_it_be(:iteration_cadence) { create(:iterations_cadence, group: group, active: true) }
      let_it_be(:iteration) do
        create(
          :iteration,
          iterations_cadence: iteration_cadence,
          group: group,
          start_date: 1.day.from_now,
          due_date: 2.days.from_now
        )
      end

      let_it_be(:iteration2) do
        create(
          :iteration,
          iterations_cadence: iteration_cadence,
          group: group,
          start_date: 2.days.ago,
          due_date: 1.day.ago,
          state: 'closed',
          skip_future_date_validation: true
        )
      end

      before do
        stub_licensed_features(iterations: true)

        project.add_developer(user)

        visit_issue(project, issue)
      end

      it 'selects and updates the right iteration', :aggregate_failures do
        within_testid('work-item-iteration') do
          click_button 'Edit'

          expect(page).to have_text(iteration_cadence.title)
          expect(page).to have_content(iteration_period(iteration, use_thin_space: false))

          select_listbox_item(iteration_period(iteration, use_thin_space: false))

          expect(page).to have_text(iteration_cadence.title)
          expect(page).to have_content(iteration_period(iteration, use_thin_space: false))

          click_button 'Edit'
          click_button 'Clear'

          expect(page).to have_text('None')
        end
      end

      context 'when searching iteration by its cadence title', :aggregate_failures do
        let_it_be(:plan_cadence) { create(:iterations_cadence, title: 'plan cadence', group: group, active: true) }
        let_it_be(:plan_iteration) do
          create(:iteration, :with_due_date, iterations_cadence: plan_cadence, start_date: 1.week.from_now)
        end

        it "returns the correct iteration" do
          within_testid('work-item-iteration') do
            click_button 'Edit'
            send_keys('plan')

            expect(page).to have_text(plan_cadence.title)
            expect(page).to have_text(iteration_period(plan_iteration, use_thin_space: false))
            expect(page).not_to have_text(iteration_cadence.title)
            expect(page).not_to have_content(iteration_period(iteration, use_thin_space: false))
            expect(page).not_to have_content(iteration_period(iteration2, use_thin_space: false))
          end
        end
      end

      it 'does not show closed iterations' do
        within_testid('work-item-iteration') do
          click_button 'Edit'

          expect(page).not_to have_text(iteration_period(iteration2, use_thin_space: false))
        end
      end
    end

    context 'when a project does not have a group' do
      before do
        stub_licensed_features(iterations: true)

        project_without_group.add_developer(user)

        visit_issue(project_without_group, issue_no_group)
      end

      it 'cannot find the select-iteration edit button' do
        expect(page).not_to have_css('[data-testid="work-item-iteration"]')
      end
    end

    context 'when iteration feature is not available' do
      before do
        stub_licensed_features(iterations: false)

        project.add_developer(user)

        visit_issue(project, issue)
      end

      it 'cannot find the select-iteration edit button' do
        expect(page).not_to have_css('[data-testid="work-item-iteration"]')
      end
    end
  end

  context 'with escalation policy' do
    it 'is not available for default issue type' do
      expect(page).not_to have_selector('.block.escalation-policy')
    end
  end

  def visit_issue(project, issue)
    visit project_issue_path(project, issue)
  end
end
