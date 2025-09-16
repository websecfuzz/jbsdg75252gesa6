# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::Chain::Populate, feature_category: :pipeline_composition do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user) }

  let(:pipeline) do
    build(:ci_pipeline, project: project, ref: 'master', user: user)
  end

  let(:command) do
    Gitlab::Ci::Pipeline::Chain::Command.new(
      project: project,
      current_user: user,
      origin_ref: 'master',
      seeds_block: nil)
  end

  let(:step) { described_class.new(pipeline, command) }

  before do
    stub_ci_pipeline_yaml_file(YAML.dump(config))
  end

  context 'when pipeline is empty and there are policy_pipelines' do
    let(:command) do
      Gitlab::Ci::Pipeline::Chain::Command.new(
        project: project,
        current_user: user,
        origin_ref: 'master',
        pipeline_policy_context: instance_double(
          Gitlab::Ci::Pipeline::ExecutionPolicies::PipelineContext,
          policy_pipelines: [build(:pipeline_execution_policy_pipeline)]),
        seeds_block: nil)
    end

    let(:config) do
      { rspec: {
        script: 'ls',
        only: ['something']
      } }
    end

    it 'does not break the chain' do
      expect(step.break?).to be false
    end

    it 'does not append an error' do
      expect(pipeline.errors).to be_empty
    end
  end
end
