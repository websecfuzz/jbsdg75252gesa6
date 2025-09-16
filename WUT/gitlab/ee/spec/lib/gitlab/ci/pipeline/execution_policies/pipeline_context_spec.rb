# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::ExecutionPolicies::PipelineContext, feature_category: :security_policy_management do
  subject(:context) { described_class.new(project: project, command: command) }

  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user, developer_of: project) }
  let(:pipeline) { build(:ci_pipeline, source: 'push', project: project, ref: 'master', user: user) }
  let(:command) do
    Gitlab::Ci::Pipeline::Chain::Command.new(
      project: project, source: pipeline.source, current_user: user, origin_ref: pipeline.ref
    )
  end

  describe 'delegations' do
    it { is_expected.to delegate_method(:policy_pipelines).to(:pipeline_execution_context) }
    it { is_expected.to delegate_method(:override_policy_stages).to(:pipeline_execution_context) }
    it { is_expected.to delegate_method(:build_policy_pipelines!).to(:pipeline_execution_context) }
    it { is_expected.to delegate_method(:creating_policy_pipeline?).to(:pipeline_execution_context) }
    it { is_expected.to delegate_method(:creating_project_pipeline?).to(:pipeline_execution_context) }
    it { is_expected.to delegate_method(:has_execution_policy_pipelines?).to(:pipeline_execution_context) }
    it { is_expected.to delegate_method(:has_overriding_execution_policy_pipelines?).to(:pipeline_execution_context) }
    it { is_expected.to delegate_method(:collect_declared_stages!).to(:pipeline_execution_context) }
    it { is_expected.to delegate_method(:inject_policy_stages?).to(:pipeline_execution_context) }
    it { is_expected.to delegate_method(:valid_stage?).to(:pipeline_execution_context) }
    it { is_expected.to delegate_method(:has_injected_stages?).to(:pipeline_execution_context) }
    it { is_expected.to delegate_method(:has_override_stages?).to(:pipeline_execution_context) }
    it { is_expected.to delegate_method(:injected_policy_stages).to(:pipeline_execution_context) }
    it { is_expected.to delegate_method(:policy_management_project_access_allowed?).to(:pipeline_execution_context) }
    it { is_expected.to delegate_method(:applying_config_override?).to(:pipeline_execution_context) }
  end

  describe '#pipeline_execution_context' do
    it 'initializes it with correct attributes' do
      expect(::Gitlab::Ci::Pipeline::PipelineExecutionPolicies::PipelineContext)
        .to receive(:new).with(context: context, project: project, command: command)

      context.pipeline_execution_context
    end
  end

  describe '#scan_execution_context' do
    it 'is memoized by ref' do
      expect(::Gitlab::Ci::Pipeline::ScanExecutionPolicies::PipelineContext).to receive(:new).with(
        project: project, ref: 'refs/heads/master', current_user: user, source: 'push').exactly(:once).and_call_original
      expect(::Gitlab::Ci::Pipeline::ScanExecutionPolicies::PipelineContext).to receive(:new).with(
        project: project, ref: 'refs/heads/main', current_user: user, source: 'push').exactly(:once).and_call_original

      2.times { context.scan_execution_context('refs/heads/master') }
      2.times { context.scan_execution_context('refs/heads/main') }
    end
  end

  describe '#skip_ci_allowed?' do
    subject { context.skip_ci_allowed?(ref: pipeline.ref) }

    it { is_expected.to be(true) }

    context 'when there are pipeline execution policies' do
      before do
        allow(context.pipeline_execution_context).to receive(:skip_ci_allowed?).and_return(allowed)
      end

      context 'when they disallow skip_ci' do
        let(:allowed) { false }

        it { is_expected.to be(false) }
      end

      context 'when they allow skip_ci' do
        let(:allowed) { true }

        it { is_expected.to be(true) }
      end
    end

    context 'when there are scan execution policies' do
      let(:skip_allowed) { true }

      before do
        scan_execution_context_double =
          instance_double(::Gitlab::Ci::Pipeline::ScanExecutionPolicies::PipelineContext,
            skip_ci_allowed?: skip_allowed)
        allow(context).to receive(:scan_execution_context).with(pipeline.ref).and_return(scan_execution_context_double)
      end

      context 'when they are allowed to be skipped' do
        let(:skip_allowed) { true }

        it { is_expected.to be(true) }
      end

      context 'when they are not allowed to be skipped' do
        let(:skip_allowed) { false }

        it { is_expected.to be(false) }
      end
    end
  end
end
