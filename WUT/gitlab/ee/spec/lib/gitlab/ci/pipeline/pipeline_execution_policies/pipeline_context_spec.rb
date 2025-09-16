# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::PipelineExecutionPolicies::PipelineContext, feature_category: :security_policy_management do
  subject(:context) { execution_policies_pipeline_context.pipeline_execution_context }

  let(:execution_policies_pipeline_context) do
    Gitlab::Ci::Pipeline::ExecutionPolicies::PipelineContext.new(project: project, command: command)
  end

  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user, developer_of: project) }
  let(:current_policy) { nil }
  let(:policy_pipelines) { [] }
  let(:source) { 'push' }
  let(:pipeline) { build(:ci_pipeline, source: source, project: project, ref: 'master', user: user) }
  let(:command_attributes) { {} }
  let(:command) do
    Gitlab::Ci::Pipeline::Chain::Command.new(
      project: project, source: pipeline.source, current_user: user, origin_ref: pipeline.ref, **command_attributes
    )
  end

  shared_context 'with mocked current_policy' do
    before do
      allow(context).to receive(:current_policy).and_return(current_policy)
    end
  end

  shared_context 'with mocked policy_pipelines' do
    before do
      allow(context).to receive(:policy_pipelines).and_return(policy_pipelines)
    end
  end

  shared_context 'with mocked policy configs' do
    let(:namespace_content) { { job: { script: 'namespace script' } } }
    let(:namespace_config) { build(:pipeline_execution_policy_config, content: namespace_content) }

    let(:project_content) { { job: { script: 'project script' } } }
    let(:project_config) { build(:pipeline_execution_policy_config, :suffix_never, content: project_content) }

    let(:policy_configs) { [project_config, namespace_config] }

    before do
      allow_next_instance_of(::Gitlab::Security::Orchestration::ProjectPipelineExecutionPolicies) do |instance|
        allow(instance).to receive(:configs).and_return(policy_configs)
      end
    end
  end

  describe '#build_policy_pipelines!' do
    subject(:perform) { context.build_policy_pipelines!(ci_testing_partition_id) }

    include_context 'with mocked policy configs'

    it 'sets policy_pipelines' do
      perform

      expect(context.policy_pipelines).to be_a(Array)
      expect(context.policy_pipelines.size).to eq(2)
    end

    it 'passes pipeline source to policy pipelines' do
      perform

      context.policy_pipelines.each do |policy_pipeline|
        expect(policy_pipeline.pipeline.source).to eq(pipeline.source)
      end
    end

    it 'passes the right shas to the pipeline' do
      perform

      context.policy_pipelines.each do |policy_pipeline|
        expect(policy_pipeline.pipeline.ref).to eq(pipeline.ref)
        expect(policy_pipeline.pipeline.before_sha).to eq(pipeline.before_sha)
        expect(policy_pipeline.pipeline.source_sha).to eq(pipeline.source_sha)
        expect(policy_pipeline.pipeline.target_sha).to eq(pipeline.target_sha)
      end
    end

    it 'propagates partition_id to policy pipelines' do
      perform

      context.policy_pipelines.each do |policy|
        expect(policy.pipeline.partition_id).to eq(ci_testing_partition_id)
      end
    end

    it_behaves_like 'policy metrics histogram', described_class::HISTOGRAMS.fetch(:single_pipeline)
    it_behaves_like 'policy metrics histogram', described_class::HISTOGRAMS.fetch(:all_pipelines)

    context 'with variables_attributes' do
      let(:command_attributes) do
        { variables_attributes: [{ key: 'CF_STANDALONE', secret_value: 'true', variable_type: 'env_var' }] }
      end

      it 'propagates it to policy pipelines', :aggregate_failures do
        perform

        context.policy_pipelines.each do |policy|
          variables = policy.pipeline.variables
          expect(variables).to be_one
          expect(variables.first).to have_attributes(key: 'CF_STANDALONE', value: 'true', variable_type: 'env_var')
        end
      end
    end

    context 'with merge_request parameter set on the command' do
      let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }
      let(:command) do
        Gitlab::Ci::Pipeline::Chain::Command.new(
          source: pipeline.source,
          project: project,
          current_user: user,
          origin_ref: merge_request.ref_path,
          merge_request: merge_request
        )
      end

      let(:project_content) do
        { job: { script: 'project script', rules: [{ when: 'always' }] } }
      end

      it 'passes the merge request to the policy pipelines' do
        perform

        context.policy_pipelines.each do |policy_pipeline|
          expect(policy_pipeline.pipeline.merge_request).to eq(merge_request)
        end
      end
    end

    context 'when a policy has strategy "override_project_ci"' do
      let(:namespace_config) do
        build(:pipeline_execution_policy_config, :override_project_ci, content: namespace_content)
      end

      it 'passes configs to policy_pipelines', :aggregate_failures do
        perform

        project_pipeline = context.policy_pipelines.first
        expect(project_pipeline.strategy_override_project_ci?).to be(false)
        expect(project_pipeline.suffix_strategy).to eq('never')
        expect(project_pipeline.suffix).to be_nil

        namespace_pipeline = context.policy_pipelines.second
        expect(namespace_pipeline.strategy_override_project_ci?).to be(true)
        expect(namespace_pipeline.suffix_strategy).to eq('on_conflict')
        expect(namespace_pipeline.suffix).to eq(':policy-123456-0')
      end
    end

    context 'when there is an error in pipeline execution policies' do
      let(:project_content) { { job: {} } }

      it 'yields the error message' do
        expect { |block| context.build_policy_pipelines!(ci_testing_partition_id, &block) }
          .to yield_with_args(a_string_including('config should implement the script'))
      end

      context 'without block' do
        it 'ignores the errored policy' do
          perform

          expect(context.policy_pipelines.size).to eq(1)
        end
      end
    end

    context 'when the policy pipeline gets filtered out by rules' do
      let(:namespace_content) do
        { job: { script: 'namespace script', rules: [{ if: '$CI_COMMIT_REF_NAME == "invalid"' }] } }
      end

      let(:project_content) do
        { job: { script: 'project script', rules: [{ if: '$CI_COMMIT_REF_NAME == "invalid"' }] } }
      end

      before do
        perform
      end

      it 'does not add it to the policy_pipelines' do
        expect(context.policy_pipelines).to be_empty
      end
    end

    context 'when creating_policy_pipeline? is true' do
      include_context 'with mocked current_policy'

      let(:current_policy) { build(:pipeline_execution_policy_config) }

      it 'does not set policy_pipelines' do
        perform

        expect(context.policy_pipelines).to be_empty
      end
    end

    context 'when pipeline execution policy configs are empty' do
      let(:policy_configs) { [] }

      it 'does not set policy_pipelines' do
        perform

        expect(context.policy_pipelines).to be_empty
      end
    end

    context 'with a dangling source' do
      Enums::Ci::Pipeline.dangling_sources.each_key do |source|
        context "when source is #{source}" do
          let(:source) { source }

          it 'does not add it to the policy_pipelines' do
            perform

            expect(context.policy_pipelines).to be_empty
          end
        end
      end
    end
  end

  describe '#creating_policy_pipeline?' do
    subject { context.creating_policy_pipeline? }

    include_context 'with mocked current_policy'

    it { is_expected.to eq(false) }

    context 'with current_policy' do
      let(:current_policy) { build(:pipeline_execution_policy_config) }

      it { is_expected.to eq(true) }
    end
  end

  describe '#policy_management_project_access_allowed?' do
    subject { context.policy_management_project_access_allowed? }

    include_context 'with mocked current_policy'

    it { is_expected.to eq(false) }

    context 'with current_policy' do
      let(:current_policy) { build(:pipeline_execution_policy_config) }

      it { is_expected.to eq(true) }
    end

    context 'when scheduled' do
      let(:command_attributes) do
        { source: ::Security::PipelineExecutionPolicies::RunScheduleWorker::PIPELINE_SOURCE }
      end

      it { is_expected.to eq(true) }
    end
  end

  describe '#creating_project_pipeline?' do
    subject { context.creating_project_pipeline? }

    include_context 'with mocked current_policy'

    it { is_expected.to eq(true) }

    context 'with current_policy' do
      let(:current_policy) { build(:pipeline_execution_policy_config) }

      it { is_expected.to eq(false) }
    end
  end

  describe '#has_execution_policy_pipelines?' do
    subject { context.has_execution_policy_pipelines? }

    include_context 'with mocked policy_pipelines'

    it { is_expected.to eq(false) }

    context 'with policy_pipelines' do
      let(:policy_pipelines) { build_list(:pipeline_execution_policy_pipeline, 2) }

      it { is_expected.to eq(true) }
    end
  end

  describe '#has_overriding_execution_policy_pipelines?' do
    subject { context.has_overriding_execution_policy_pipelines? }

    include_context 'with mocked policy configs'

    context 'without policy configs' do
      let(:policy_configs) { [] }

      it { is_expected.to eq(false) }
    end

    context 'with policy configs' do
      let(:policy_configs) { [project_config, namespace_config] }

      include_context 'with mocked policy_pipelines'

      it { is_expected.to eq(false) }

      context 'and at least one config having strategy override_project_ci' do
        let(:namespace_config) do
          build(:pipeline_execution_policy_config, :override_project_ci, content: namespace_content)
        end

        it { is_expected.to eq(true) }

        context 'with a dangling source' do
          Enums::Ci::Pipeline.dangling_sources.each_key do |source|
            context "when source is #{source}" do
              let(:source) { source }

              it { is_expected.to eq(false) }
            end
          end
        end
      end
    end
  end

  describe '#applying_config_override?' do
    using RSpec::Parameterized::TableSyntax

    subject { context.applying_config_override? }

    where(:has_overriding_policies, :creating_project_pipeline, :expected_result) do
      true  | false | false
      true  | true | true
      false | true  | false
      false | false | false
    end

    with_them do
      before do
        allow(context).to receive_messages(
          has_overriding_execution_policy_pipelines?: has_overriding_policies,
          creating_project_pipeline?: creating_project_pipeline
        )
      end

      it { is_expected.to eq(expected_result) }
    end
  end

  describe '#inject_policy_stages?' do
    subject { context.inject_policy_stages? }

    it { is_expected.to eq(false) }

    context 'with current_policy' do
      let(:current_policy) { build(:pipeline_execution_policy_config) }

      include_context 'with mocked current_policy'

      it { is_expected.to eq(true) }
    end

    context 'with policy_pipelines' do
      let(:policy_pipelines) { build_list(:ci_empty_pipeline, 2) }

      include_context 'with mocked policy_pipelines'

      it { is_expected.to eq(true) }
    end

    context 'when scheduled' do
      let(:command_attributes) do
        { source: ::Security::PipelineExecutionPolicies::RunScheduleWorker::PIPELINE_SOURCE }
      end

      it { is_expected.to eq(true) }

      context 'with feature disabled' do
        before do
          stub_feature_flags(scheduled_pipeline_execution_policies: false)
        end

        it { is_expected.to eq(false) }
      end
    end
  end

  describe '#valid_stage?' do
    subject { context.valid_stage?(stage) }

    include_context 'with mocked current_policy'

    let(:stage) { 'test' }

    it { is_expected.to eq(true) }

    %w[.pipeline-policy-pre .pipeline-policy-post].each do |stage|
      context "when stage is #{stage}" do
        let(:stage) { stage }

        it { is_expected.to eq(false) }

        context 'with current_policy' do
          let(:current_policy) { build(:pipeline_execution_policy_config) }

          it { is_expected.to eq(true) }
        end

        context "when scheduled" do
          let(:command_attributes) do
            { source: ::Security::PipelineExecutionPolicies::RunScheduleWorker::PIPELINE_SOURCE }
          end

          it { is_expected.to eq(true) }

          context 'with feature disabled' do
            before do
              stub_feature_flags(scheduled_pipeline_execution_policies: false)
            end

            it { is_expected.to eq(false) }
          end
        end
      end
    end
  end

  describe '#collect_declared_stages!' do
    using RSpec::Parameterized::TableSyntax

    include_context 'with mocked current_policy'

    context 'with override_project_ci' do
      let(:current_policy) { build(:pipeline_execution_policy_config, :override_project_ci) }

      context 'when adding compatible stages' do
        where(:stages1, :stages2, :result) do
          []                                | %w[test]                          | %w[test]
          %w[test]                          | %w[build test]                    | %w[build test]
          %w[build test]                    | %w[test]                          | %w[build test]
          %w[build test]                    | %w[build test]                    | %w[build test]
          %w[build test deploy]             | %w[build deploy]                  | %w[build test deploy]
          %w[build test deploy]             | %w[test deploy]                   | %w[build test deploy]
          %w[build test policy-test deploy] | %w[build test deploy]             | %w[build test policy-test deploy]
          %w[policy-test]                   | %w[build test policy-test deploy] | %w[build test policy-test deploy]
        end

        with_them do
          it 'sets the largest set of stages as override_policy_stages' do
            context.collect_declared_stages!(stages1)
            context.collect_declared_stages!(stages2)

            expect(context.override_policy_stages).to eq(result)
            expect(context.injected_policy_stages).to be_empty
          end

          context 'when creating a project pipeline' do
            let(:current_policy) { nil }

            it 'does not collect the stages' do
              context.collect_declared_stages!(stages1)
              context.collect_declared_stages!(stages2)

              expect(context.override_policy_stages).to be_empty
              expect(context.injected_policy_stages).to be_empty
            end
          end
        end
      end

      context 'when adding incompatible stages' do
        where(:stages1, :stages2) do
          %w[test]              | %w[build]
          %w[build test]        | %w[test build]
          %w[build test]        | %w[test deploy]
          %w[build other]       | %w[build test deploy]
          %w[build deploy]      | %w[deploy test build]
          %w[deploy test build] | %w[build deploy]
          %w[deploy test build] | %w[build other]
          %w[deploy test]       | %w[build policy-build test policy-test deploy]
        end

        with_them do
          it 'raises an error' do
            context.collect_declared_stages!(stages1)

            expect { context.collect_declared_stages!(stages2) }
              .to raise_error(::Gitlab::Ci::Pipeline::PipelineExecutionPolicies::OverrideStagesConflictError)
          end
        end
      end
    end

    context 'with inject_ci' do
      let(:current_policy) { build(:pipeline_execution_policy_config) }

      it 'does not affect the resulting stages' do
        context.collect_declared_stages!(%w[build test])

        expect(context.override_policy_stages).to be_empty
        expect(context.injected_policy_stages).to be_empty
      end
    end

    context 'with inject_policy' do
      let(:current_policy) { build(:pipeline_execution_policy_config, :inject_policy) }
      let(:stages1) do
        %w[.pipeline-policy-pre .pre build test policy-test .post .pipeline-policy-post]
      end

      let(:stages2) do
        %w[.pipeline-policy-pre .pre policy-build .post .pipeline-policy-post]
      end

      it 'includes stages from all policies' do
        context.collect_declared_stages!(stages1)
        context.collect_declared_stages!(stages2)

        expect(context.override_policy_stages).to be_empty
        expect(context.injected_policy_stages).to contain_exactly(stages1, stages2)
      end

      context 'when creating a project pipeline' do
        let(:current_policy) { nil }

        it 'does not collect the stages' do
          context.collect_declared_stages!(stages1)
          context.collect_declared_stages!(stages2)

          expect(context.override_policy_stages).to be_empty
          expect(context.injected_policy_stages).to be_empty
        end
      end
    end
  end

  describe '#has_override_stages?' do
    subject { context.has_override_stages? }

    let(:stages) do
      %w[.pipeline-policy-pre .pre policy-test .post .pipeline-policy-post]
    end

    context 'when no override stages are collected' do
      it { is_expected.to be(false) }
    end

    context 'with override stages' do
      before do
        allow(context).to receive(:override_policy_stages).and_return(stages)
      end

      it { is_expected.to be(true) }

      context 'when collected stages are empty' do
        let(:stages) { [] }

        it { is_expected.to be(false) }
      end
    end
  end

  describe '#has_injected_stages?' do
    subject { context.has_injected_stages? }

    let(:stages) do
      %w[.pipeline-policy-pre .pre build test policy-test .post .pipeline-policy-post]
    end

    context 'when no stages are collected' do
      it { is_expected.to be(false) }
    end

    context 'when stages are injected' do
      before do
        allow(context).to receive(:injected_policy_stages).and_return(stages)
      end

      it { is_expected.to be(true) }
    end
  end

  describe '#skip_ci_allowed?' do
    subject { context.skip_ci_allowed? }

    include_context 'with mocked policy_pipelines'

    it { is_expected.to eq(true) }

    context 'with policy_pipelines' do
      context 'without skip_ci specified' do
        let(:policy_pipelines) { build_list(:pipeline_execution_policy_pipeline, 2) }

        it { is_expected.to eq(false) }
      end

      context 'when all policy_pipelines allows skip_ci' do
        let(:policy_pipelines) { build_list(:pipeline_execution_policy_pipeline, 2, :skip_ci_allowed) }

        it { is_expected.to eq(true) }
      end

      context 'when at least one policy_pipeline disallows skip_ci' do
        let(:policy_pipelines) do
          [
            *build_list(:pipeline_execution_policy_pipeline, 2, :skip_ci_allowed),
            *build_list(:pipeline_execution_policy_pipeline, 2, :skip_ci_disallowed)
          ]
        end

        it { is_expected.to eq(false) }
      end
    end
  end

  describe '#job_options' do
    subject(:job_options) { context.job_options }

    include_context 'with mocked current_policy'

    context 'when building policy pipeline' do
      let(:current_policy) do
        build(:pipeline_execution_policy_config,
          policy: build(:pipeline_execution_policy, :variables_override_disallowed, name: 'My policy'))
      end

      it 'includes policy-specific options' do
        expect(job_options).to eq(execution_policy_job: true, execution_policy_name: 'My policy',
          execution_policy_variables_override: { allowed: false })
      end
    end

    context 'when building project pipeline' do
      it { is_expected.to eq({}) }
    end
  end
end
