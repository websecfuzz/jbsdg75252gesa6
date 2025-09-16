# frozen_string_literal: true

module ConstructPipelineExecutionSchedulePolicies
  extend ActiveSupport::Concern
  include ConstructSecurityPoliciesSharedAttributes

  def construct_pipeline_execution_schedule_policies(policies)
    policies.map do |policy|
      construct_pipeline_execution_schedule_policy(policy)
    end
  end

  def construct_pipeline_execution_schedule_policy(policy, with_policy_attributes = false)
    warnings = []

    policy_attributes = base_policy_attributes(policy).merge(
      policy_blob_file_path: policy_blob_file_path(policy, warnings),
      warnings: warnings
    )

    policy_hash = {
      name: policy[:name],
      description: policy[:description],
      edit_path: edit_path(policy, :pipeline_execution_schedule_policy),
      enabled: policy[:enabled],
      policy_scope: policy_scope(policy[:policy_scope]),
      yaml: YAML.dump(
        policy.slice(
          *POLICY_YAML_ATTRIBUTES,
          :content,
          :schedules,
          :metadata
        ).deep_stringify_keys
      ),
      updated_at: policy[:config].policy_last_updated_at,
      csp: policy[:csp]
    }

    policy_hash.merge(policy_specific_attributes(policy[:type], policy_attributes, with_policy_attributes))
  end
end
