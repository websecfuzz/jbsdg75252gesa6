# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::LimitService, feature_category: :security_policy_management do
  let_it_be(:group) { create(:group) }
  let(:service) { described_class.new(container: group) }

  describe '#pipeline_execution_policies_per_pipeline_limit' do
    subject(:limit) { service.pipeline_execution_policies_per_pipeline_limit }

    it 'returns the default limit' do
      expect(limit).to eq(5)
    end
  end

  describe '#pipeline_execution_policies_per_configuration_limit' do
    subject(:limit) { service.pipeline_execution_policies_per_configuration_limit }

    context 'when both root ancestor and current settings have limits set' do
      before do
        allow(group.root_ancestor).to receive(:pipeline_execution_policies_per_configuration_limit)
          .and_return(group_level_setting)
        allow(Gitlab::CurrentSettings).to receive(:pipeline_execution_policies_per_configuration_limit).and_return(7)
      end

      context 'when current setting is set to non-zero value' do
        let(:group_level_setting) { 3 }

        it 'returns the group-level setting' do
          expect(limit).to eq(3)
        end
      end

      context 'when current setting is set to 0' do
        let(:group_level_setting) { 0 }

        it 'returns the root ancestor limit' do
          expect(limit).to eq(7)
        end
      end
    end

    context 'when only root ancestor limit is set' do
      before do
        allow(group.root_ancestor).to receive(:pipeline_execution_policies_per_configuration_limit).and_return(4)
        allow(Gitlab::CurrentSettings).to receive(:pipeline_execution_policies_per_configuration_limit).and_return(nil)
      end

      it 'returns the root ancestor limit' do
        expect(limit).to eq(4)
      end
    end

    context 'when only current settings limit is set' do
      before do
        allow(group.root_ancestor).to receive(:pipeline_execution_policies_per_configuration_limit).and_return(nil)
        allow(Gitlab::CurrentSettings).to receive(:pipeline_execution_policies_per_configuration_limit).and_return(6)
      end

      it 'returns the current settings limit' do
        expect(limit).to eq(6)
      end
    end

    context 'when no limits are set' do
      before do
        allow(group.root_ancestor).to receive(:pipeline_execution_policies_per_configuration_limit).and_return(nil)
        allow(Gitlab::CurrentSettings).to receive(:pipeline_execution_policies_per_configuration_limit).and_return(nil)
      end

      it 'returns the default limit' do
        expect(limit).to eq(5)
      end
    end
  end
end
