# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project
        module Pipeline
          module Show
            extend QA::Page::PageConcern

            def self.prepended(base)
              super

              base.class_eval do
                include Page::Component::LicenseManagement
                include Page::Component::SecureReport

                view 'app/assets/javascripts/ci/reports/components/report_item.vue' do
                  element 'report-item-row'
                end

                view 'ee/app/assets/javascripts/security_dashboard/components/pipeline/' \
                  'pipeline_security_dashboard.vue' do
                  element 'pipeline-vulnerability-report'
                end
              end
            end

            def click_on_security
              retry_until(sleep_interval: 3, message: "Security report didn't open") do
                click_link('Security')
                has_element?('pipeline-vulnerability-report')
              end
            end

            def click_on_licenses
              click_link('Licenses')
            end

            def has_license?(name)
              has_element?('report-item-row', text: name)
            end

            def wait_for_pipeline_job_replication(name)
              QA::Runtime::Logger.debug(%(#{self.class.name} - wait_for_pipeline_job_replication))
              wait_until(max_duration: Runtime::Geo.max_file_replication_time) do
                has_job?(name)
              end
            end
          end
        end
      end
    end
  end
end
