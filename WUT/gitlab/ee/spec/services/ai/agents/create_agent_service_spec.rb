# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::Agents::CreateAgentService, feature_category: :mlops do
  let_it_be(:user) { create(:user) }
  let_it_be(:existing_agent) { create(:ai_agent) }
  let_it_be(:another_project) { create(:project) }
  let_it_be(:prompt) { 'prompt' }

  subject(:create_agent) { described_class.new(project, name, prompt).execute }

  describe '#execute' do
    context 'when agent name does not exist in the project' do
      let(:name) { 'new_agent' }
      let(:project) { existing_agent.project }

      it 'creates an agent', :aggregate_failures do
        expect { create_agent }.to change { Ai::Agent.count }.by(1).and change { Ai::AgentVersion.count }.by(1)

        expect(create_agent.name).to eq(name)
      end
    end

    context 'when agent name exists but project is different' do
      let(:name) { existing_agent.name }
      let(:project) { another_project }

      it 'creates an agent', :aggregate_failures do
        expect { create_agent }.to change { Ai::Agent.count }.by(1).and change { Ai::AgentVersion.count }.by(1)

        expect(create_agent.name).to eq(name)
      end
    end

    context 'when model with name exists' do
      let(:name) { existing_agent.name }
      let(:project) { existing_agent.project }

      it 'returns a model with errors', :aggregate_failures do
        expect(create_agent).not_to be_persisted
        expect(create_agent.errors.full_messages).to eq(["Name has already been taken"])
      end
    end

    context 'when a prompt is not supplied' do
      let(:name) { 'new_agent' }
      let(:project) { existing_agent.project }
      let(:prompt) { nil }

      it 'returns a model with errors', :aggregate_failures do
        expect(create_agent).not_to be_persisted
        expect(create_agent.errors.full_messages).to eq(["Versions is invalid"])
        expect(create_agent.versions.first.errors.full_messages).to eq(["Prompt can't be blank"])
      end
    end
  end
end
