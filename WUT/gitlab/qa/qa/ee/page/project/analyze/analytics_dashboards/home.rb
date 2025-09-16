# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project
        module Analyze
          module AnalyticsDashboards
            class Home < QA::Page::Base
              view 'ee/app/assets/javascripts/analytics/analytics_dashboards/components/list/dashboard_list_item.vue' do
                element 'dashboard-list-item'
                element 'dashboard-router-link'
                element 'dashboard-errors-badge'
              end

              view 'ee/app/assets/javascripts/analytics/analytics_dashboards/components/dashboards_list.vue' do
                element 'configure-dashboard-container'
                element 'new-dashboard-button'
                element 'data-explorer-button'
              end

              def wait_for_dashboards_list
                has_element?('dashboard-router-link', wait: 120)
              end

              def dashboards_list
                all_elements('dashboard-router-link', minimum: 2)
              end

              def open_audience_dashboard
                open_dashboard('Audience')
              end

              def open_behavior_dashboard
                open_dashboard('Behavior')
              end

              def click_configure_dashboard_project
                within_element('configure-dashboard-container') do
                  click_element('.btn-confirm')
                end
              end

              def click_data_explorer_button
                click_element('data-explorer-button')
              end

              def click_new_dashboard_button
                click_element('new-dashboard-button')
              end

              def open_dashboard(name)
                click_link(name)
                wait_for_requests
              end

              def has_dashboard_item?(name)
                has_element?('dashboard-router-link', text: name, wait: 10)
              end

              def list_item_has_errors_badge?(name:, wait: 1)
                within_element('dashboard-list-item', text: name) do
                  has_element?('dashboard-errors-badge', wait: wait)
                end
              end
            end
          end
        end
      end
    end
  end
end
