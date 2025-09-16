# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanExecutionPolicy::Config, feature_category: :security_policy_management do
  let(:config) { described_class.new(**params) }
  let(:params) { { policy: policy } }

  describe '#actions' do
    subject { config.actions }

    let(:policy) { build(:scan_execution_policy, actions: [{ scan: 'secret_detection' }]) }

    it { is_expected.to eq([{ scan: 'secret_detection' }]) }
  end

  describe '#skip_ci_allowed?' do
    let(:policy) { build(:scan_execution_policy, skip_ci: skip_ci_config) }

    context 'when skip_ci is not configured' do
      let(:skip_ci_config) { nil }

      it 'returns true for any user' do
        expect(config.skip_ci_allowed?(123)).to be true
        expect(config.skip_ci_allowed?(456)).to be true
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

      it 'returns false for allowed users' do
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
