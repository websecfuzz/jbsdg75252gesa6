# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::Catalog::Agent::Delete, feature_category: :workflow_catalog do
  include GraphqlHelpers

  let_it_be(:maintainer) { create(:user) }
  let_it_be(:project) { create(:project, maintainers: maintainer) }
  let_it_be_with_reload(:agent) { create(:ai_catalog_item, :with_version, project: project) }

  let(:current_user) { maintainer }
  let(:mutation) { graphql_mutation(:ai_catalog_agent_delete, params) }
  let(:params) do
    {
      id: agent.to_global_id
    }
  end

  subject(:execute) { post_graphql_mutation(mutation, current_user: current_user) }

  shared_examples 'an authorization failure' do
    it_behaves_like 'a mutation that returns a top-level access error'

    it 'does not delete the catalog item' do
      expect { execute }.not_to change { Ai::Catalog::Item.count }
    end
  end

  context 'when user is a developer' do
    let(:current_user) { create(:user).tap { |user| project.add_developer(user) } }

    it_behaves_like 'an authorization failure'
  end

  context 'when global_ai_catalog feature flag is disabled' do
    before do
      stub_feature_flags(global_ai_catalog: false)
    end

    it_behaves_like 'an authorization failure'
  end

  context 'when the agent does not exist' do
    let(:params) do
      {
        id: Gitlab::GlobalId.build(model_name: 'Ai::Catalog::Item', id: non_existing_record_id)
      }
    end

    it_behaves_like 'an authorization failure'
  end

  context 'when destroy service fails' do
    before do
      allow_next_instance_of(::Ai::Catalog::Agents::DestroyService) do |service|
        allow(service).to receive(:agent).and_return(agent)
      end
      allow(agent).to receive(:destroy).and_return(false)
      agent.errors.add(:base, 'Deletion failed')
    end

    it 'returns the service error message' do
      execute

      expect(graphql_data_at(:ai_catalog_agent_delete, :errors)).to contain_exactly('Deletion failed')
      expect(graphql_data_at(:ai_catalog_agent_delete, :success)).to be(false)
    end
  end

  context 'when destroy service succeeds' do
    it 'destroy the agent and returns a success response' do
      expect { execute }.to change { Ai::Catalog::Item.count }.by(-1)
      expect(graphql_data_at(:ai_catalog_agent_delete, :success)).to be(true)
    end

    it 'destroy the agent versions' do
      expect { execute }.to change { Ai::Catalog::ItemVersion.count }.by(-1)
    end
  end
end
