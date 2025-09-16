# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project
        module Settings
          class Analytics < QA::Page::Base
            include QA::Page::Settings::Common

            view 'ee/app/views/projects/settings/analytics/_custom_dashboard_projects.html.haml' do
              element 'analytics-dashboards-settings'
            end

            view 'ee/app/views/projects/settings/analytics/_configurator_settings.haml' do
              element 'snowplow-configurator-field'
            end

            view 'ee/app/views/projects/settings/analytics/_product_analytics.html.haml' do
              element 'collector-host-field'
              element 'cube-api-url-field'
              element 'cube-api-key-field'
              element 'save-changes-button'
            end

            def set_dashboards_configuration_project(project)
              within_element('analytics-dashboards-settings') do
                click_element('base-dropdown-toggle')
                wait_for_requests
                find('.gl-listbox-search-input').set(project.name)
                click_element("listbox-item-#{project.id}")
                click_element('.btn-confirm')
              end
            end

            def fill_snowplow_configurator(configurator)
              fill_element('snowplow-configurator-field', configurator)
            end

            def fill_collector_host(collector_host)
              fill_element('collector-host-field', collector_host)
            end

            def fill_cube_api_url(url)
              fill_element('cube-api-url-field', url)
            end

            def fill_cube_api_key(key)
              fill_element('cube-api-key-field', key)
            end

            def save_changes
              click_element('save-changes-button')
            end
          end
        end
      end
    end
  end
end
