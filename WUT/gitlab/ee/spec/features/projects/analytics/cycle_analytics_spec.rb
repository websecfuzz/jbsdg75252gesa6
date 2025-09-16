# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Project > Value stream analytics', :js, feature_category: :value_stream_management do
  include CycleAnalyticsHelpers
  include ListboxHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:guest) { create(:user) }
  let_it_be(:auditor) { create(:user, auditor: true) }
  let_it_be(:group) { create(:group, :with_organization, name: 'CA-test-group', owners: user) }
  let_it_be(:project) { create(:project, :repository, namespace: group, name: 'Cool fun project') }
  let_it_be(:project_namespace) { project.project_namespace }

  let(:empty_state_selector) { '[data-testid="vsa-empty-state"]' }
  let(:value_stream_selector) { '[data-testid="dropdown-value-streams"]' }
  let(:duration_chart_selector) { '[data-testid="vsa-duration-overview-chart"]' }
  let(:metrics_groups_selector) { '[data-testid="vsa-metrics-group"]' }
  let(:task_by_type_chart_selector) { '[data-testid="vsa-task-type-chart"]' }
  let(:metrics_selector) { '[data-testid="vsa-metrics"]' }

  shared_examples 'Unlicensed Value Stream Analytics' do
    before do
      visit project_cycle_analytics_path(project)
    end

    it 'does not render the premium features' do
      expect(page).not_to have_selector(value_stream_selector)
      expect(page).not_to have_selector(duration_chart_selector)
    end

    it 'renders vsa metrics' do
      metrics_groups = page.all(metrics_groups_selector)
      expect(metrics_groups.count).to eq(1)

      expect(metrics_groups.first).to have_content "Lifecycle metrics"

      aggregate_failures 'with relevant values' do
        expect(vsa_metrics_titles.length).to eq 3
        expect(vsa_metrics_titles).to match_array ['New issues', 'Commits', 'Deploys']

        expect(vsa_metrics_values).to match_array ["-"] * 3
      end
    end
  end

  context 'with cycle_analytics_for_projects licensed feature available' do
    let_it_be(:group) { create(:group, :with_organization, name: 'Project with custom value streams available') }
    let_it_be(:project) do
      create(:project, :repository, namespace: group, name: 'Important project')
    end

    let_it_be(:project_namespace) { project.project_namespace }

    before do
      stub_licensed_features(
        cycle_analytics_for_projects: true,
        cycle_analytics_for_groups: true,
        group_level_analytics_dashboard: true
      )
    end

    context 'as user' do
      before do
        project.add_maintainer(user)
        sign_in(user)
      end

      context 'with no value stream' do
        it 'renders the customizable VSA empty state' do
          visit project_cycle_analytics_path(project)

          expect(page).to have_selector(empty_state_selector)
          expect(page).to have_text(s_('CycleAnalytics|Custom value streams to measure your DevSecOps lifecycle'))
        end

        it 'allows to create a custom value stream' do
          visit project_cycle_analytics_path(project)
          find_by_testid('create-value-stream-button').click
          wait_for_requests

          fill_in('Value Stream name', with: 'foo stream')
          click_button('New value stream')
          # otherwise we get the "Data is collecting and loading"
          create_value_stream_aggregation(project_namespace)
          refresh

          wait_for_requests

          expect(page).to have_content('foo stream')
          expect(page).to have_selector(duration_chart_selector)

          expect(page).to have_selector(metrics_selector)
          aggregate_failures 'with relevant values' do
            expect(vsa_metrics_titles.length).to eq 5
            expect(vsa_metrics_titles).to match_array ["Commits", "Cycle time", "Deploys", "Lead time", "New issues"]
          end
        end
      end

      context 'with a custom value stream created', :sidekiq_inline do
        def visit_custom_value_stream
          # otherwise we get the "Data is collecting and loading"
          create_value_stream_aggregation(project_namespace)

          visit project_cycle_analytics_path(project)
          wait_for_requests
          find(value_stream_selector).click
          select_listbox_item(value_stream_name)
          wait_for_requests
        end

        let_it_be(:value_stream_name) { 'custom stream' }
        let_it_be(:stages) do
          [
            create(:cycle_analytics_stage, namespace: project_namespace, name: "Issue", relative_position: 1,
              start_event_identifier: :issue_created, end_event_identifier: :issue_closed),
            create(:cycle_analytics_stage, namespace: project_namespace, name: "Code", relative_position: 2)
          ]
        end

        let_it_be(:value_stream) do
          create(:cycle_analytics_value_stream,
            namespace: project_namespace,
            name: value_stream_name,
            stages: stages)
        end

        context 'on overview section' do
          def create_overview_data
            issue = travel_to(3.days.ago.end_of_day) { create(:issue, project: project) }

            travel_to(2.days.ago.end_of_day) do
              create_commit_referencing_issue(issue)
              create_merge_request_closing_issue(user, project, issue)
            end

            merge_merge_requests_closing_issue(user, project, issue)

            travel_to(5.days.ago.end_of_day) { create_deployment(project: project) }
            create_deployment(project: project)
          end

          before do
            travel_to Time.now.utc.beginning_of_day

            create_overview_data
          end

          it 'displays data' do
            visit_custom_value_stream

            expect(page).to have_content('Overview')

            aggregate_failures 'with metric values' do
              expect(page).to have_css '#lead_time div', text: 2
              expect(page).to have_css '#cycle_time div', text: 1
              expect(page).to have_css '#issues div', text: 1
              expect(page).to have_css '#commits div', text: 2
              expect(page).to have_css '#deploys div', text: 2
            end

            # Not available on Premium level
            expect(page).not_to have_css '#lead_time_for_changes'
            expect(page).not_to have_css '#time_to_restore_service'
            expect(page).not_to have_css '#change_failure_rate'

            expect(page).not_to have_content(_('Value Streams Dashboard | DORA'))
          end

          context "when the user has access to the project's group" do
            before do
              group.add_developer(user)
            end

            it 'displays the link to VSD' do
              visit_custom_value_stream

              expect(page).to have_content('Overview')
              expect(page).to have_content(_('Value Streams Dashboard | DORA'))
            end
          end

          context 'as guest' do
            before do
              project.add_guest(guest)
              sign_in(guest)

              visit_custom_value_stream
            end

            it 'renders vsa metrics' do
              aggregate_failures 'with relevant values' do
                expect(vsa_metrics_titles.length).to eq 4
                expect(vsa_metrics_titles).to match_array ["Cycle time", "Deploys", "Lead time", "New issues"]

                expect(vsa_metrics_values).to match_array %w[1 1 2 2]
              end
            end
          end

          context 'as auditor' do
            before do
              sign_in(auditor)

              visit_custom_value_stream
            end

            it 'renders vsa metrics' do
              aggregate_failures 'with relevant values' do
                expect(vsa_metrics_titles.length).to eq 4
                expect(vsa_metrics_titles).to match_array ["Cycle time", "Deploys", "Lead time", "New issues"]

                expect(vsa_metrics_values).to match_array %w[1 1 2 2]
              end
            end
          end

          it 'does not render task by type chart' do
            task_by_type_chart_selector
            # Only rendered at group level
            expect(page).not_to have_selector(task_by_type_chart_selector)
          end
        end

        context 'on total time chart' do
          context 'when there is no data' do
            it 'renders empty state' do
              visit_custom_value_stream

              expect(page).to have_content(
                _('No data available ' \
                  'Try adjusting the filters, or creating an issue or merge request to collect more data')
              )
            end
          end

          context 'when there is data' do
            def create_total_time_chart_data
              issue_1 = travel_to(4.days.ago.end_of_day) { create(:issue, project: project) }
              issue_1.close
            end

            before do
              create_total_time_chart_data
              visit_custom_value_stream
            end

            it 'displays data on chart' do
              expect(page).not_to have_content(
                _('No data available ' \
                  'Try adjusting the filters, or creating an issue or merge request to collect more data')
              )
              page.within(duration_chart_selector) do
                expect(page).to have_content('Average time to completion')
              end
            end
          end
        end
      end
    end
  end

  context 'with `cycle_analytics_for_projects` disabled' do
    before do
      stub_licensed_features(cycle_analytics_for_projects: false)

      project.add_maintainer(user)
      sign_in(user)
    end

    it_behaves_like 'Unlicensed Value Stream Analytics'
  end
end
