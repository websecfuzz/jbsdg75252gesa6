# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::Agents::CreateAgentVersionService, feature_category: :mlops do
  let_it_be(:agent) { create(:ai_agent) }
  let_it_be(:prompt) { 'prompt' }

  subject(:service) { described_class.new(agent, prompt) }

  describe '#build' do
    it 'builds an agent version', :aggregate_failures do
      expect { service.build }.not_to change { Ai::AgentVersion.count }
    end
  end

  describe '#execute' do
    it 'creates an agent version', :aggregate_failures do
      expect { service.execute }.to change { Ai::AgentVersion.count }.by(1)
    end
  end
end
