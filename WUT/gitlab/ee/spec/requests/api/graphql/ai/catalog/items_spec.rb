# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting AI catalog items', feature_category: :workflow_catalog do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:deleted_catalog_item) { create(:ai_catalog_item, project: project, public: true, deleted_at: 1.day.ago) }
  let(:nodes) { graphql_data_at(:ai_catalog_items, :nodes) }
  let(:current_user) { nil }
  let(:args) { {} }

  let(:query) do
    "{ #{query_nodes('AiCatalogItems', max_depth: 3, args: args)} }"
  end

  shared_examples 'a successful query' do
    it 'returns AI not deleted catalog items' do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(nodes).to match_array(catalog_items.map { |item| a_graphql_entity_for(item) })
    end
  end

  shared_examples 'an unsuccessful query' do
    it 'returns no AI catalog items' do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(nodes).to be_empty
    end
  end

  context 'with public catalog items' do
    let_it_be(:catalog_items) { create_list(:ai_catalog_item, 2, project: project, public: true) }

    it_behaves_like 'a successful query'

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(global_ai_catalog: false)
      end

      it_behaves_like 'an unsuccessful query'
    end
  end

  context 'with private catalog items' do
    let_it_be(:catalog_items) { create_list(:ai_catalog_item, 2, project: project) }

    context 'when developer' do
      let(:current_user) do
        create(:user).tap { |user| project.add_developer(user) }
      end

      it_behaves_like 'a successful query'
    end

    context 'when reporter' do
      let(:current_user) do
        create(:user).tap { |user| project.add_reporter(user) }
      end

      it_behaves_like 'an unsuccessful query'
    end
  end

  it 'returns catalog item versions without N+1 database queries' do
    catalog_item_1, catalog_item_2 = create_list(:ai_catalog_item, 2, project: project, public: true)

    post_graphql(query, current_user: nil) # Warm up

    create(:ai_catalog_item_version, item: catalog_item_1)
    create(:ai_catalog_item_version, item: catalog_item_2)

    control_count = ActiveRecord::QueryRecorder.new do
      post_graphql(query, current_user: nil)
    end

    create(:ai_catalog_item_version, item: catalog_item_1, version: 'v1.0.1')
    create(:ai_catalog_item_version, item: catalog_item_2, version: 'v1.0.1')

    expect do
      post_graphql(query, current_user: nil)
    end.not_to exceed_query_limit(control_count)

    expect(graphql_data_at(:ai_catalog_items, :nodes, :versions, :nodes).size).to eq(4)
    expect(graphql_data_at(:ai_catalog_items, :nodes, :latest_version).compact.size).to eq(2)
  end

  describe 'item_type argument' do
    let_it_be(:agent_type_item) { create(:ai_catalog_item, item_type: :agent, project: project, public: true) }
    let_it_be(:flow_type_item) { create(:ai_catalog_item, item_type: :flow, project: project, public: true) }

    context 'when not provided' do
      it 'returns all catalog items' do
        post_graphql(query, current_user: current_user)

        expect(nodes).to contain_exactly(a_graphql_entity_for(agent_type_item), a_graphql_entity_for(flow_type_item))
      end
    end

    context 'when agent' do
      let(:args) { { item_type: :AGENT } }

      it 'returns only agents' do
        post_graphql(query, current_user: current_user)

        expect(nodes).to contain_exactly(a_graphql_entity_for(agent_type_item))
      end
    end
  end
end
