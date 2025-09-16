# frozen_string_literal: true

module EE
  module Ci
    module PipelineProcessing
      module AtomicProcessingService
        extend ::Gitlab::Utils::Override
        include ::Gitlab::Utils::StrongMemoize

        private

        override :status_of_previous_jobs_dag
        def status_of_previous_jobs_dag(job)
          status = super

          calculate_status_based_on_policy_pre_stage(status, job)
        end

        # Returns a running status for previous jobs as long as the
        # pipeline-policy-pre stage is not completed. This is to
        # ensure jobs can not circumvent enforces security checks.
        def calculate_status_based_on_policy_pre_stage(status, job)
          return status if !policy_pre_stage || job_on_policy_pre_stage?(job)

          policy_pre_stage_completed? ? status : 'running'
        end

        def job_on_policy_pre_stage?(job)
          job.stage == ::Gitlab::Ci::Pipeline::PipelineExecutionPolicies::ReservedStagesInjector::PRE_STAGE
        end

        def policy_pre_stage_completed?
          ::Ci::HasStatus::COMPLETED_STATUSES.include?(collection.status_of_stage(policy_pre_stage.position))
        end
        strong_memoize_attr :policy_pre_stage_completed?

        def policy_pre_stage
          pipeline.stages.find do |stage|
            stage.name == ::Gitlab::Ci::Pipeline::PipelineExecutionPolicies::ReservedStagesInjector::PRE_STAGE
          end
        end
        strong_memoize_attr :policy_pre_stage
      end
    end
  end
end
