# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::PipelineExecutionPolicies::CustomStagesInjector, feature_category: :security_policy_management do
  using RSpec::Parameterized::TableSyntax

  subject(:injected_stages) { described_class.inject(wrap_stages(project_stages), injected_policy_stages) }

  let(:project_stages) { %w[build test deploy] }

  context 'with valid stages' do
    where(:project_stages, :policy_stages, :result) do
      %w[build test deploy] | %w[policy-test] | %w[build test deploy policy-test]
      %w[build test deploy] | %w[policy-test test] | %w[build policy-test test deploy]
      %w[build test deploy] | %w[build policy-test test] | %w[build policy-test test deploy]
      %w[build test deploy] | %w[build policy-test] | %w[build test deploy policy-test]
      %w[build test deploy] | %w[policy-test build test] | %w[policy-test build test deploy]
      %w[test post-test deploy] | %w[test policy-test deploy] | %w[test post-test policy-test deploy]
      %w[compile check
        publish] | %w[build test policy-test deploy] | %w[compile check publish build test policy-test deploy]
      %w[compile check
        publish] | %w[compile build check test policy-test deploy
          publish] | %w[compile build check test policy-test deploy publish]
    end

    with_them do
      let(:injected_policy_stages) { [wrap_stages(policy_stages)] }

      it 'inserts custom stages based on their dependencies' do
        expect(injected_stages).to eq(wrap_stages(result))
      end
    end

    context 'with multiple policies' do
      where(:policy1, :policy2, :result) do
        %w[build policy-build test] | %w[build test policy-test deploy] | %w[build policy-build test policy-test deploy]
        %w[build policy-build test] | %w[test deploy policy-deploy] | %w[build policy-build test deploy policy-deploy]
        %w[build policy-test test] | %w[build policy-compile test] | %w[build policy-test policy-compile test deploy]
        %w[policy1-test] | %w[policy2-test] | %w[build test deploy policy1-test policy2-test]
      end

      with_them do
        let(:injected_policy_stages) { [wrap_stages(policy1), wrap_stages(policy2)] }

        it 'inserts custom stages in order from all policies based on their dependencies' do
          expect(injected_stages).to eq(wrap_stages(result))
        end
      end
    end
  end

  context 'when there are cyclic dependencies within injected stages' do
    let(:injected_policy_stages) do
      [
        wrap_stages(%w[test deploy]),
        wrap_stages(%w[deploy test])
      ]
    end

    it 'raises an error' do
      expect { injected_stages }
        .to raise_error(described_class::InvalidStageConditionError, /Cyclic dependencies/)
    end
  end

  context 'when there are cyclic dependencies with project config' do
    let(:project_stages) { %w[deploy build test] }
    let(:injected_policy_stages) { [wrap_stages(%w[build test policy-test deploy])] }

    it 'raises an error' do
      expect { injected_stages }
        .to raise_error(described_class::InvalidStageConditionError, /Cyclic dependencies/)
    end
  end

  private

  def wrap_stages(stages)
    ['.pipeline-policy-pre', '.pre', *stages, '.post', '.pipeline-policy-post']
  end
end
