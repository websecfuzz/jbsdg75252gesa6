# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ProcessScanResultPolicyWorker, feature_category: :security_policy_management do
  let_it_be(:configuration, refind: true) { create(:security_orchestration_policy_configuration, configured_at: nil) }

  it_behaves_like 'an idempotent worker' do
    let(:job_args) { [configuration.project.id, configuration.id] }
  end

  describe '#perform' do
    subject(:worker) { described_class.new }

    it 'does nothing' do
      expect(worker.perform(configuration.project.id, configuration.id)).to be_nil
    end
  end
end
