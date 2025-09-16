# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::Agents::UpdateAgentService, feature_category: :mlops do
  let_it_be(:user) { create(:user) }
  let_it_be(:agent_version) { create(:ai_agent_version) }
  let_it_be(:agent) { agent_version.agent }
  let_it_be(:another_project) { create(:project) }
  let_it_be(:prompt) { 'prompt' }
  let_it_be(:name) { 'name' }

  subject(:updated_agent) { described_class.new(agent, name, prompt).execute }

  describe '#execute' do
    context 'when attributes are valid' do
      let(:name) { 'new_agent_name' }
      let(:prompt) { 'new_prompt' }
      let(:project) { agent.project }

      it 'updates an agent', :aggregate_failures do
        expect(updated_agent.reload.name).to eq(name)
        expect(updated_agent.latest_version.prompt).to eq(prompt)
      end
    end

    context 'when an invalid name is supplied' do
      let(:name) { 'invalid name' }

      it 'returns a model with errors', :aggregate_failures do
        expect(updated_agent.errors.full_messages).to eq(["Name is invalid"])
      end
    end

    context 'when the agent version can not be saved' do
      it 'returns a model with errors', :aggregate_failures do
        agent.latest_version.model = nil

        expect(updated_agent.errors.full_messages).to eq(["Latest version is invalid"])
      end
    end
  end
end
