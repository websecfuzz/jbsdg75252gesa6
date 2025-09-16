# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::Chain::Command, feature_category: :continuous_integration do
  let_it_be(:project) { create(:project, :repository) }

  describe '#dry_run?' do
    subject { command.dry_run? }

    let(:command) { described_class.new(dry_run: dry_run, pipeline_policy_context: pipeline_policy_context) }
    let(:dry_run) { false }
    let(:pipeline_policy_context) { nil }

    it { is_expected.to eq(false) }

    context 'when dry_run is true' do
      let(:dry_run) { true }

      it { is_expected.to eq(true) }
    end

    context 'with pipeline_policy_context' do
      let(:creating_policy_pipeline) { false }
      let(:pipeline_policy_context) do
        instance_double(Gitlab::Ci::Pipeline::ExecutionPolicies::PipelineContext,
          creating_policy_pipeline?: creating_policy_pipeline)
      end

      it { is_expected.to eq(false) }

      context 'when creating_policy_pipeline? is true' do
        let(:creating_policy_pipeline) { true }

        it { is_expected.to eq(true) }
      end
    end
  end

  describe '#increment_duplicate_job_name_errors_counter' do
    let(:command) { described_class.new }
    let(:suffix_strategy) { 'never' }

    subject(:increment) { command.increment_duplicate_job_name_errors_counter(suffix_strategy) }

    it 'increments the error metric' do
      counter = Gitlab::Metrics.counter(:gitlab_ci_duplicate_job_name_errors_counter, 'desc')
      expect { increment }.to change { counter.get(suffix_strategy: suffix_strategy) }.by(1)
    end
  end
end
