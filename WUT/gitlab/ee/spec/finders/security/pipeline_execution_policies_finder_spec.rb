# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PipelineExecutionPoliciesFinder, feature_category: :security_policy_management do
  let!(:policy) do
    build(:pipeline_execution_policy, name: 'Contains custom pipeline configuration', policy_scope: policy_scope)
  end

  let!(:policy_yaml) do
    build(:orchestration_policy_yaml, pipeline_execution_policy: [policy])
  end

  include_context 'with security policies information'

  it_behaves_like 'security policies finder'
end
