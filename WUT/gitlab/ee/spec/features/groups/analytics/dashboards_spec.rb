# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Analytics Dashboards', :js, feature_category: :value_stream_management do
  include ValueStreamsDashboardHelpers
  include DoraMetricsDashboardHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:user) { current_user }
  let_it_be(:group) { create(:group, name: "vsd test group") }
  let_it_be(:project) { create(:project, :repository, name: "vsd project", group: group) }
  let_it_be(:custom_vsd_fixture_path) { 'ee/spec/fixtures/analytics/valid_value_stream_dashboard_configuration.yaml' }

  it 'renders a 403 error for a user without permission' do
    sign_in(user)
    visit group_analytics_dashboards_path(group)

    expect(page).to have_content _(" You do not have the permission to access this page")
  end

  context 'with a valid user' do
    before_all do
      group.add_developer(user)
    end

    context 'with group_level_analytics_dashboard license' do
      before do
        stub_licensed_features(group_level_analytics_dashboard: true, dora4_analytics: true, security_dashboard: true,
          cycle_analytics_for_groups: true)

        sign_in(user)
      end

      context 'for dashboard listing' do
        before do
          visit_group_analytics_dashboards_list(group)
        end

        it 'renders the dashboard list correctly' do
          expect(page).to have_content _('Analytics dashboards')
          expect(page).to have_content _('Dashboards are created by editing the groups dashboard files')
        end

        context 'when a custom dashboard exists' do
          let_it_be(:pointer_project) { create(:project, :repository, group: group) }

          before_all do
            create(:analytics_dashboards_pointer, namespace: group, target_project: pointer_project)
            create_custom_yaml_config(user, pointer_project, custom_vsd_fixture_path)
          end

          it 'renders custom dashboard link' do
            dashboard_items = page.all(dashboard_list_item_testid)

            vsd_dashboard = dashboard_items[0]
            contribution_dashboard = dashboard_items[1]
            dora_metrics_dashboard = dashboard_items[2]
            custom_dashboard = dashboard_items[3]

            expect(dashboard_items.length).to eq(4)

            expect(vsd_dashboard).to have_content _('Value Streams Dashboard')
            expect(vsd_dashboard).to have_selector(dashboard_by_gitlab_testid)

            expect(contribution_dashboard).to have_content _('Contributions Dashboard')
            expect(contribution_dashboard).to have_selector(dashboard_by_gitlab_testid)

            expect(dora_metrics_dashboard).to have_content _('DORA metrics analytics')
            expect(dora_metrics_dashboard).to have_selector(dashboard_by_gitlab_testid)

            expect(custom_dashboard).to have_content _('Custom VSD')
            expect(custom_dashboard).to have_content _('VSD from fixture')
            expect(custom_dashboard).not_to have_selector(dashboard_by_gitlab_testid)
          end
        end

        it_behaves_like 'has value streams dashboard link'

        context 'with dora_metrics_dashboard disabled' do
          before do
            stub_feature_flags(dora_metrics_dashboard: false)

            visit_group_analytics_dashboards_list(group)
          end

          it 'does not render DORA metrics dashboard link' do
            dashboard_items_arr = page.all(dashboard_list_item_title).map(&:text)

            expect(dashboard_items_arr).not_to include('DORA metrics analytics')
          end
        end
      end

      context 'for Value Streams Dashboard' do
        context 'with default configuration' do
          before do
            visit_group_value_streams_dashboard(group)
          end

          it_behaves_like 'VSD renders as an analytics dashboard'
        end

        context 'with usage overview background aggregation enabled' do
          before do
            create(:value_stream_dashboard_aggregation, namespace: group, enabled: true)

            visit_group_value_streams_dashboard(group)
          end

          it_behaves_like 'does not render usage overview background aggregation not enabled alert'
        end

        context 'with valid custom configuration' do
          let_it_be(:pointer_project) { create(:project, :repository, group: group) }

          before_all do
            create(:analytics_dashboards_pointer, namespace: group, target_project: pointer_project)
            create_custom_yaml_config(user, pointer_project, custom_vsd_fixture_path)
          end

          before do
            visit_group_value_streams_dashboard(group, 'Custom VSD')
          end

          it 'renders custom VSD' do
            within find_by_testid('dashboard-description') do |panel|
              expect(panel).to have_content _('VSD from fixture')
            end
            within find_by_testid('gridstack-grid') do |panel|
              expect(panel).to have_content _('Custom Panel 1')
            end
            within find_by_testid('vsd-feedback-survey') do |feedback_survey|
              expect(feedback_survey).to be_visible
              expect(feedback_survey).to have_content _("To help us improve the Value Stream Management Dashboard, " \
                "please share feedback about your experience in this survey.")
            end
          end

          it 'does not render 404 when refreshing the page' do
            visit current_path

            within find_by_testid('dashboard-description') do |panel|
              expect(panel).to have_content _('VSD from fixture')
            end
          end
        end

        context 'with invalid custom configuration' do
          let_it_be(:pointer_project) { create(:project, :repository, group: group) }
          let_it_be(:invalid_custom_vsd_fixture_path) do
            'ee/spec/fixtures/analytics/invalid_value_stream_dashboard_configuration.yaml'
          end

          before_all do
            create(:analytics_dashboards_pointer, namespace: group, target_project: pointer_project)
            create_custom_yaml_config(user, pointer_project, invalid_custom_vsd_fixture_path)
          end

          before do
            visit_group_value_streams_dashboard(group, 'Invalid VSD')
          end

          it 'renders error' do
            find_by_testid('panel-not-exists').hover

            expect(page).to have_content(_('Something is wrong with your panel visualization configuration.'))
            expect(page).to have_link(text: 'troubleshooting documentation')
          end
        end
      end

      context 'for DORA metrics analytics dashboard' do
        context 'without data available' do
          before do
            visit_group_dora_metrics_dashboard(group)
          end

          it_behaves_like 'DORA metrics analytics renders as an analytics dashboard'

          it_behaves_like 'renders DORA metrics stats with zero values'

          it_behaves_like 'renders DORA metrics chart panels with empty states'
        end

        context 'with data available' do
          let_it_be(:environment) { create(:environment, :production, project: project) }

          before do
            create_mock_dora_metrics(environment)

            visit_group_dora_metrics_dashboard(group)
          end

          it_behaves_like 'DORA metrics analytics renders as an analytics dashboard'

          it_behaves_like 'renders DORA metrics analytics stats' do
            let(:expected_dora_metrics_stats) { ['0.1 /day', '26.1 %', '5.0 days', '3.0 days'] }
          end

          it_behaves_like 'renders DORA metrics time series charts'

          it_behaves_like 'updates DORA metrics visualizations when filters applied', days_back: 90 do
            let(:filtered_dora_metrics_stats) { ['0.2 /day', '33.3 %', '4.0 days', '2.0 days'] }
          end
        end
      end
    end
  end
end
