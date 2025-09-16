# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PipelineExecutionPolicy::Config, feature_category: :security_policy_management do
  let(:config) { described_class.new(**params) }
  let(:params) { { policy_project_id: 123, policy_index: 1, policy: policy } }

  describe '#strategy_override_project_ci?' do
    subject { config.strategy_override_project_ci? }

    context 'with inject_ci' do
      let(:policy) { build(:pipeline_execution_policy, pipeline_config_strategy: 'inject_ci') }

      it { is_expected.to be(false) }
    end

    context 'with override_project_ci' do
      let(:policy) { build(:pipeline_execution_policy, pipeline_config_strategy: 'override_project_ci') }

      it { is_expected.to be(true) }
    end
  end

  describe '#strategy_inject_policy?' do
    subject { config.strategy_inject_policy? }

    context 'with inject_ci' do
      let(:policy) { build(:pipeline_execution_policy, pipeline_config_strategy: 'inject_ci') }

      it { is_expected.to be(false) }
    end

    context 'with inject_policy' do
      let(:policy) { build(:pipeline_execution_policy, pipeline_config_strategy: 'inject_policy') }

      it { is_expected.to be(true) }
    end
  end

  describe '#suffix' do
    subject { config.suffix }

    context 'when policy has suffix "on_conflict"' do
      let(:policy) { build(:pipeline_execution_policy, suffix: 'on_conflict') }

      it { is_expected.to eq ':policy-123-1' }
    end

    context 'when policy has no suffix specified' do
      let(:policy) { build(:pipeline_execution_policy, suffix: nil) }

      it { is_expected.to eq ':policy-123-1' }
    end

    context 'when policy has suffix "never"' do
      let(:policy) { build(:pipeline_execution_policy, suffix: 'never') }

      it { is_expected.to be_nil }
    end
  end

  describe '#skip_ci_allowed?' do
    let(:policy) { build(:pipeline_execution_policy, skip_ci: skip_ci_config) }

    context 'when skip_ci is not configured' do
      let(:skip_ci_config) { {} }

      it 'returns false for any user' do
        expect(config.skip_ci_allowed?(123)).to be false
        expect(config.skip_ci_allowed?(456)).to be false
      end
    end

    context 'when skip_ci is allowed without allowlist' do
      let(:skip_ci_config) { { allowed: true } }

      it 'returns true for any user' do
        expect(config.skip_ci_allowed?(123)).to be true
        expect(config.skip_ci_allowed?(456)).to be true
      end
    end

    context 'when skip_ci is disallowed without allowlist' do
      let(:skip_ci_config) { { allowed: false } }

      it 'returns false for any user' do
        expect(config.skip_ci_allowed?(123)).to be false
        expect(config.skip_ci_allowed?(456)).to be false
      end
    end

    context 'when skip_ci is allowed with allowlist' do
      let(:skip_ci_config) { { allowed: true, allowlist: { users: [{ id: 123 }, { id: 456 }] } } }

      it 'returns true for allowed users' do
        expect(config.skip_ci_allowed?(123)).to be true
        expect(config.skip_ci_allowed?(456)).to be true
      end

      it 'returns true for non-allowed users' do
        expect(config.skip_ci_allowed?(789)).to be true
      end
    end

    context 'when skip_ci is disallowed with allowlist' do
      let(:skip_ci_config) { { allowed: false, allowlist: { users: [{ id: 123 }, { id: 456 }] } } }

      it 'returns true for allowed users' do
        expect(config.skip_ci_allowed?(123)).to be true
        expect(config.skip_ci_allowed?(456)).to be true
      end

      it 'returns false for non-allowed users' do
        expect(config.skip_ci_allowed?(789)).to be false
      end
    end
  end
end
