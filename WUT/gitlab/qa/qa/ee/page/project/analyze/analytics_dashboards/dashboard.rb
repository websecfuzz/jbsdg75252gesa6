# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project
        module Analyze
          module AnalyticsDashboards
            class Dashboard < QA::Page::Base
              view 'app/assets/javascripts/vue_shared/components/' \
                   'customizable_dashboard/gridstack_wrapper.vue' do
                element 'grid-stack-panel'
              end

              view 'app/assets/javascripts/vue_shared/components/' \
                   'customizable_dashboard/customizable_dashboard.vue' do
                element 'dashboard-edit-btn'
              end

              view 'ee/app/assets/javascripts/analytics/analytics_dashboards/components/' \
                     'analytics_dashboard.vue' do
                element 'analytics-dashboard-invalid-config-alert'
              end

              def panels
                all_elements('grid-stack-panel', minimum: 1)
              end

              def panel(panel_index:)
                panels[panel_index]
              end

              def audience_dashboard_panels
                all_elements('grid-stack-panel', minimum: 9)
              end

              def behavior_dashboard_panels
                all_elements('grid-stack-panel', minimum: 5)
              end

              def panel_title(panel_index:)
                within_element_by_index('grid-stack-panel', panel_index) do
                  find_element('panel-title').text
                end
              end

              def panel_value_content(panel_index:)
                wait_until do
                  within_element_by_index('grid-stack-panel', panel_index) { has_element?('displayValue') }
                end

                within_element_by_index('grid-stack-panel', panel_index) do
                  find_element('displayValue').text.to_i
                end
              end

              def table_value(panel_index:, cell_index:)
                wait_until do
                  within_element_by_index('grid-stack-panel', panel_index) { has_element?('td[role=cell]') }
                end

                within_element_by_index('grid-stack-panel', panel_index) do
                  all_elements('td[role=cell]', minimum: 1)[cell_index].text.to_i
                end
              end

              def panel_has_chart?(panel_index:)
                within_element_by_index('grid-stack-panel', panel_index) do
                  has_css?('svg')
                end
              end

              def panel_chart_legend(panel_index:)
                within_element_by_index('grid-stack-panel', panel_index) do
                  find_element('gl-chart-legend').text
                end
              end

              def edit_dashboard
                click_element 'dashboard-edit-btn'
              end

              def has_invalid_config_alert?(wait: 1)
                has_element?('analytics-dashboard-invalid-config-alert', wait: wait)
              end
            end
          end
        end
      end
    end
  end
end
