# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Creation of an AI agent', feature_category: :mlops do
  include GraphqlHelpers

  let_it_be(:agent) { create(:ai_agent) }
  let_it_be(:project) { agent.project }
  let_it_be(:current_user) { project.owner }

  let(:input) { { project_path: project.full_path, name: name, prompt: prompt } }
  let(:name) { 'some_name' }
  let(:prompt) { 'A prompt' }

  let(:mutation) { graphql_mutation(:ai_agent_create, input) }
  let(:mutation_response) { graphql_mutation_response(:ai_agent_create) }

  before do
    stub_licensed_features(ai_agents: true)
  end

  context 'when user is not allowed write changes' do
    before do
      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?)
                          .with(current_user, :write_ai_agents, project)
                          .and_return(false)
    end

    it_behaves_like 'a mutation that returns a top-level access error'
  end

  context 'when user is allowed write changes' do
    it 'creates an agent' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['agent']).to include(
        'name' => name
      )
    end

    context 'when name already exists' do
      err_msg = "Name has already been taken"
      let(:name) { agent.name }

      it_behaves_like 'a mutation that returns errors in the response', errors: [err_msg]
    end
  end
end
