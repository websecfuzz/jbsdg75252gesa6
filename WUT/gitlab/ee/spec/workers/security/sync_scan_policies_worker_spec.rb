# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SyncScanPoliciesWorker, feature_category: :security_policy_management do
  describe '#perform' do
    let_it_be(:configuration) { create(:security_orchestration_policy_configuration, configured_at: nil) }

    subject(:worker) { described_class.new }

    include_examples 'an idempotent worker' do
      let(:job_args) { [configuration.id, { 'force_resync' => false }] }
    end

    it 'has the `until_executed` deduplicate strategy' do
      expect(described_class.get_deduplicate_strategy).to eq(:until_executed)
    end

    it 'calls update_policy_configuration' do
      expect(worker).to receive(:update_policy_configuration).with(configuration, false)

      worker.perform(configuration.id)
    end

    it 'does not call update_policy_configuration when configuration is not present' do
      expect(worker).not_to receive(:update_policy_configuration)

      worker.perform(non_existing_record_id)
    end

    context 'when force_resync is true' do
      it 'calls update_policy_configuration with force_resync: true' do
        expect(worker).to receive(:update_policy_configuration).with(configuration, true)

        worker.perform(configuration.id, { 'force_resync' => true })
      end
    end
  end
end
