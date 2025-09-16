# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Milestones on EE', feature_category: :team_planning do
  let(:user) { create(:user) }
  let(:project) { create(:project, name: 'test', namespace: user.namespace) }
  let(:milestone) { create(:milestone, project: project, start_date: Date.today, due_date: 7.days.from_now) }

  before do
    login_as(user)
  end

  def visit_milestone
    visit project_milestone_path(project, milestone)
  end

  context 'burndown charts' do
    let(:milestone) do
      create(:milestone, project: project, start_date: Date.yesterday, due_date: Date.tomorrow)
    end

    context 'with no issues' do
      it 'shows a mention to add issues' do
        visit_milestone

        expect(page).to have_content 'Assign some issues to this milestone.'
      end
    end

    context 'with the milestone charts feature available' do
      before do
        create(:issue, project: project, assignees: [user], author: user, milestone: milestone)
        stub_licensed_features(milestone_charts: true)
      end

      it 'does not show a mention to add issues' do
        visit_milestone

        expect(page).not_to have_content 'Assign some issues to this milestone.'
      end

      it 'shows a burndown chart' do
        visit_milestone

        within('#content-body') do
          expect(page).to have_selector('.burndown-chart')
        end
      end

      context 'with due & start date not set' do
        let(:milestone_without_dates) { create(:milestone, project: project) }

        it 'shows a mention to fill in dates' do
          visit project_milestone_path(project, milestone_without_dates)

          expect(find_by_testid('no-issues-and-dates-alert')).to have_content('Add a start date and due date')
        end
      end
    end

    shared_examples 'burndown charts disabled' do
      it 'has a link to upgrade to Bronze when checking the namespace plan' do
        # Not using `stub_application_setting` because the method is prepended in
        # `EE::ApplicationSetting` which breaks when using `any_instance`
        # https://gitlab.com/gitlab-org/gitlab-foss/issues/33587
        allow(Gitlab::CurrentSettings.current_application_settings)
          .to receive(:should_check_namespace_plan?).and_return(true)

        visit_milestone

        within('#content-body') do
          expect(page).not_to have_selector('.burndown-chart')
        end
      end

      it 'has a link to upgrade to starter on premise' do
        allow(Gitlab::CurrentSettings.current_application_settings)
          .to receive(:should_check_namespace_plan?).and_return(false)

        visit_milestone

        within('#content-body') do
          expect(page).not_to have_selector('.burndown-chart')
        end
      end
    end

    context 'with the milestone charts feature disabled' do
      before do
        stub_licensed_features(milestone_charts: false)
      end

      include_examples 'burndown charts disabled'
    end

    context 'with the issuable weights feature disabled' do
      before do
        stub_licensed_features(issue_weights: false)
      end

      include_examples 'burndown charts disabled'
    end
  end

  context 'milestone summary' do
    it 'shows the total weight when sum is greater than zero' do
      create(:issue, project: project, milestone: milestone, weight: 3)
      create(:issue, project: project, milestone: milestone, weight: 1)

      visit_milestone

      within '.milestone-sidebar' do
        expect(page).to have_content 'Total weight 4'
      end
    end

    it 'hides the total weight when sum is equal to zero' do
      create(:issue, project: project, milestone: milestone, weight: nil)
      create(:issue, project: project, milestone: milestone, weight: nil)

      visit_milestone

      within '.milestone-sidebar' do
        expect(page).to have_content 'Total weight None'
      end
    end
  end
end
