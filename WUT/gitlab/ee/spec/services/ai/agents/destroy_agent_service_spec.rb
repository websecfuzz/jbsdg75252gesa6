# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::Agents::DestroyAgentService, feature_category: :mlops do
  let_it_be(:user) { create(:user) }
  let_it_be(:agent_version) { create(:ai_agent_version) }
  let_it_be(:agent) { agent_version.agent }

  let(:service) { described_class.new(agent, user) }

  describe '#execute' do
    subject(:service_result) { service.execute }

    context 'when agent fails to delete' do
      it 'returns nil' do
        exception = ActiveRecord::RecordNotDestroyed.new(agent)
        allow(agent).to receive(:destroy).and_raise(exception)

        expect(service_result).to be_error
        expect(service_result.message).to eq("Failed to delete AI Agent: #{exception.message}")
      end
    end

    context 'when an agent exists' do
      it 'destroys the agent', :aggregate_failures do
        expect { service_result }.to change { Ai::Agent.count }.by(-1).and change { Ai::AgentVersion.count }.by(-1)
        expect(service_result).to be_success
      end
    end
  end
end
