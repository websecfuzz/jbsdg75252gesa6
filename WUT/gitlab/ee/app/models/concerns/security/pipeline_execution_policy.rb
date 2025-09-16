# frozen_string_literal: true

module Security
  module PipelineExecutionPolicy
    POLICY_TYPE_NAME = 'Pipeline execution policy'

    def active_pipeline_execution_policies
      pipeline_execution_policy.select { |config| config[:enabled] }.first(pipeline_execution_policy_limit)
    end

    def active_pipeline_execution_policy_names
      active_pipeline_execution_policies.pluck(:name) # rubocop:disable Database/AvoidUsingPluckWithoutLimit -- not an ActiveRecord model and active_pipeline_execution_policies has limit
    end

    def pipeline_execution_policy
      policy_by_type(:pipeline_execution_policy)
    end

    private

    def pipeline_execution_policy_limit
      Security::SecurityOrchestrationPolicies::LimitService
        .new(container: source)
        .pipeline_execution_policies_per_configuration_limit
    end
  end
end
