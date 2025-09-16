# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting consumed AI catalog items', feature_category: :workflow_catalog do
  include GraphqlHelpers

  let_it_be(:developer) { create(:user) }
  let_it_be(:project) { create(:project, :public, developers: developer) }
  let_it_be(:catalog_items) { create_list(:ai_catalog_item, 2) }
  let_it_be(:configured_items) do
    catalog_items.map { |item| create(:ai_catalog_item_consumer, project: project, item: item) }
  end

  let(:current_user) { developer }
  let(:project_gid) { project.to_global_id }
  let(:nodes) { graphql_data_at(:configured_ai_catalog_items, :nodes) }

  let(:query) do
    <<~GRAPHQL
    {
      configuredAiCatalogItems(projectId: "#{project_gid}") {
        nodes {
          #{all_graphql_fields_for('AiCatalogItemConsumer', max_depth: 1)}
          project { id }
          item { id }
        }
      }
    }
    GRAPHQL
  end

  it 'returns configured AI catalog items' do
    post_graphql(query, current_user: current_user)

    expect(response).to have_gitlab_http_status(:success)
    expect(nodes).to match_array(configured_items.map { |configured_item| a_graphql_entity_for(configured_item) })
  end

  it 'avoids N+1 queries' do
    # Warm up the cache
    post_graphql(query, current_user: current_user)

    control = ActiveRecord::QueryRecorder.new { post_graphql(query, current_user: current_user) }

    create(:ai_catalog_item_consumer, project: project)

    expect { post_graphql(query, current_user: current_user) }.not_to exceed_query_limit(control)
  end

  context 'with project reporter' do
    let(:reporter) { create(:user) }

    it 'returns no configured AI catalog items' do
      post_graphql(query, current_user: reporter)

      expect(response).to have_gitlab_http_status(:success)
      expect(nodes).to be_empty
    end
  end

  context 'with an invalid project_id' do
    let(:project_gid) { "gid://gitlab/Project/#{non_existing_record_id}" }

    it 'returns no configured AI catalog items' do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(nodes).to be_empty
    end
  end

  context 'when feature flag is disabled' do
    before do
      stub_feature_flags(global_ai_catalog: false)
    end

    it 'returns no configured AI catalog items' do
      post_graphql(query, current_user: nil)

      expect(response).to have_gitlab_http_status(:success)
      expect(nodes).to be_empty
    end
  end
end
