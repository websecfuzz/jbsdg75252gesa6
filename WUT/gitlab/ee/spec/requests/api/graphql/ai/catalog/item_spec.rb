# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting an AI catalog item', feature_category: :workflow_catalog do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:catalog_item) { create(:ai_catalog_item, :with_version, project: project, public: true) }

  let(:latest_version) { catalog_item.latest_version }
  let(:data) { graphql_data_at(:ai_catalog_item) }
  let(:params) { { id: catalog_item.to_global_id } }
  let(:current_user) { nil }

  let(:query) do
    <<~GRAPHQL
      fragment VersionFragment on AiCatalogItemVersion {
        id
        updatedAt
        createdAt
        publishedAt
        versionName
        ... on AiCatalogAgentVersion {
          systemPrompt
          userPrompt
        }
      }

      query {
        aiCatalogItem(id: "#{params[:id]}") {
          description
          id
          itemType
          name
          public
          project { id }
          latestVersion {
            ...VersionFragment
          }
          versions {
            count
            nodes {
              ...VersionFragment
            }
          }
        }
      }
    GRAPHQL
  end

  shared_examples 'a successful query' do
    it 'returns the AI catalog item with its versions' do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(data).to match(
        hash_including(
          'id' => catalog_item.to_global_id.to_s,
          'name' => catalog_item.name,
          'description' => catalog_item.description,
          'itemType' => 'AGENT',
          'public' => catalog_item.public,
          'latestVersion' => a_graphql_entity_for(latest_version),
          'versions' => hash_including(
            'count' => 1,
            'nodes' => contain_exactly(
              hash_including(
                'id' => latest_version.to_global_id.to_s,
                'systemPrompt' => latest_version.definition['system_prompt'],
                'userPrompt' => latest_version.definition['user_prompt'],
                'updatedAt' => latest_version.updated_at.iso8601,
                'publishedAt' => latest_version.release_date&.iso8601,
                'versionName' => latest_version.version,
                'createdAt' => latest_version.created_at.iso8601
              )
            )
          )
        )
      )
    end

    context 'with a deleted catalog item' do
      let_it_be(:catalog_item) { create(:ai_catalog_item, project: project, deleted_at: 1.day.ago) }

      context 'when owner' do
        let(:current_user) do
          create(:user).tap { |user| project.add_owner(user) }
        end

        it_behaves_like 'an unsuccessful query'
      end
    end
  end

  shared_examples 'an unsuccessful query' do
    it 'returns nil' do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(data).to be_nil
    end
  end

  context 'with a public catalog item' do
    it_behaves_like 'a successful query'

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(global_ai_catalog: false)
      end

      it_behaves_like 'an unsuccessful query'
    end

    context 'when the item does not exist' do
      let(:params) { { id: global_id_of(id: non_existing_record_id, model_name: 'Ai::Catalog::Item') } }

      it_behaves_like 'an unsuccessful query'
    end
  end

  context 'with a private catalog item' do
    let_it_be(:catalog_item) { create(:ai_catalog_item, :with_version, project: project) }

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

  it 'returns the latest version when more than one exists' do
    latest_version = create(:ai_catalog_item_version, version: '2.1.0', item: catalog_item)

    post_graphql(query, current_user: nil)

    expect(response).to have_gitlab_http_status(:success)
    expect(data).to match(
      a_graphql_entity_for(
        catalog_item,
        'latestVersion' => a_graphql_entity_for(latest_version)
      )
    )
  end
end
