# frozen_string_literal: true

module QA
  RSpec.describe 'Monitor' do
    describe(
      'Product Analytics',
      only: { condition: -> { ENV["CI_PROJECT_PATH_SLUG"]&.include? "product-analytics" } },
      product_group: :platform_insights
    ) do
      let!(:group) { create(:group, name: "product-analytics-g-#{SecureRandom.hex(8)}") }
      let!(:project) do
        create(:project, :with_readme, name: "project-analytics-p-#{SecureRandom.hex(8)}", group: group)
      end

      let(:sdk_host) { Runtime::Env.pa_collector_host }
      let(:custom_dashboard_title) { 'My New Custom Dashboard' }

      let(:new_custom_dashboard_title) { 'Edited Dashboard' }

      before do
        Flow::Login.sign_in
        EE::Flow::ProductAnalytics.activate(project)
      end

      it 'custom dashboard can be edited',
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/458782' do
        sdk_app_id = 0

        EE::Page::Project::Analyze::AnalyticsDashboards::Setup.perform do |analytics_dashboards_setup|
          analytics_dashboards_setup.wait_for_sdk_containers
          sdk_app_id = analytics_dashboards_setup.sdk_application_id.value
        end

        Vendor::Snowplow::ProductAnalytics::Event.perform do |event|
          payload = event.build_payload(sdk_app_id)
          event.send(sdk_host, payload)
        end

        EE::Page::Project::Analyze::AnalyticsDashboards::Home.perform do |analytics_dashboards|
          analytics_dashboards.wait_for_dashboards_list
          analytics_dashboards.click_new_dashboard_button
        end

        EE::Page::Project::Analyze::DashboardSetup.perform do |dashboard|
          dashboard.set_dashboard_title(custom_dashboard_title)
          dashboard.click_add_visualisation
          dashboard.check_total_events
          dashboard.click_add_to_dashboard
          dashboard.click_save_your_dashboard
        end

        EE::Page::Project::Analyze::AnalyticsDashboards::Dashboard.perform(&:edit_dashboard)

        EE::Page::Project::Analyze::DashboardSetup.perform do |dashboard|
          dashboard.delete_panel(panel_index: 0)
          dashboard.click_add_visualisation
          dashboard.check_events_over_time
          dashboard.click_add_to_dashboard
          dashboard.set_dashboard_title(new_custom_dashboard_title)
          dashboard.click_save_your_dashboard
        end

        Page::Project::Menu.perform(&:go_to_analytics_dashboards)

        EE::Page::Project::Analyze::AnalyticsDashboards::Home.perform do |analytics_dashboards|
          expect(analytics_dashboards.has_dashboard_item?(new_custom_dashboard_title)).to be(true)
          expect(analytics_dashboards.list_item_has_errors_badge?(name: new_custom_dashboard_title)).to be(false)

          analytics_dashboards.open_dashboard(new_custom_dashboard_title)
        end

        EE::Page::Project::Analyze::AnalyticsDashboards::Dashboard.perform do |dashboard|
          panels = dashboard.panels
          aggregate_failures 'test edited dashboard' do
            expect(panels.count).to equal(1)
            expect(dashboard.has_invalid_config_alert?).to be(false)
            expect(dashboard.panel_title(panel_index: 0)).to eq('Events over time')
            expect(dashboard.panel_has_chart?(panel_index: 0)).to be(true)
          end
        end
      end
    end
  end
end
