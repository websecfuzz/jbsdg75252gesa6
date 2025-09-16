# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project
        module Job
          module Show
            extend QA::Page::PageConcern

            def self.prepended(base)
              super

              base.class_eval do
                view 'ee/app/assets/javascripts/ci/job_details/components/root_cause_analysis_button.vue' do
                  element 'rca-duo-button'
                end
              end
            end

            # These wait times cover both the time for pipeline job to complete and time for log and artifact to Geo replicate, so the max duration has been doubled
            def wait_for_job_log_replication
              QA::Runtime::Logger.debug(%(#{self.class.name} - wait_for_job_log_replication))
              wait_until(max_duration: 2 * Runtime::Geo.max_file_replication_time) do
                has_job_log?
              end
            end

            def wait_for_job_artifact_replication
              QA::Runtime::Logger.debug(%(#{self.class.name} - wait_for_job_artifact_replication))
              wait_until(max_duration: 2 * Runtime::Geo.max_file_replication_time) do
                has_browse_button?
              end
            end

            def click_duo_troubleshoot_button
              click_element('rca-duo-button')
            end
          end
        end
      end
    end
  end
end
