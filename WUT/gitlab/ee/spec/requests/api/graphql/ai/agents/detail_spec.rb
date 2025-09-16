# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Get details of an AI agent', feature_category: :mlops do
  include GraphqlHelpers

  let_it_be(:agent) { create(:ai_agent) }
  let_it_be(:project) { agent.project }
  let_it_be(:current_user) { project.owner }

  let(:ai_agent_data) { graphql_data_at(:project, :ai_agent) }

  let(:query) do
    %(
      query {
        project(fullPath: "#{project.full_path}") {
          aiAgent(id: "#{global_id_of(agent)}") {
            id
            name
            versions {
              id
              prompt
            }
          }
        }
      }
    )
  end

  subject(:request) { post_graphql(query, current_user: current_user) }

  before do
    stub_licensed_features(ai_agents: true)
  end

  context 'when user is not allowed read agents' do
    before do
      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?)
                          .with(current_user, :read_ai_agents, project)
                          .and_return(false)
    end

    it 'does not return agent data' do
      request

      expect(ai_agent_data).to be_nil
    end
  end

  context 'when user is allowed read agents' do
    it 'returns the agent data' do
      request

      expect(ai_agent_data['name']).to eq(agent.name)
    end
  end
end
