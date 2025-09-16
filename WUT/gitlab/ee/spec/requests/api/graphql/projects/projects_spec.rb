# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting a collection of projects', feature_category: :groups_and_projects do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group, name: 'public-group', developers: current_user) }
  let_it_be(:projects) { create_list(:project, 5, :public, group: group) }

  let_it_be(:path) { %i[projects nodes] }

  let(:filters) { {} }

  let(:query) do
    graphql_query_for(
      :projects,
      filters,
      "nodes {#{all_graphql_fields_for('Project', max_depth: 1, excluded: ['productAnalyticsState'])} }"
    )
  end

  shared_examples 'a working graphql query that returns data' do
    before do
      post_graphql(query, current_user: current_user)
    end

    it 'returns data' do
      expect(graphql_errors).to be_nil
      expect(graphql_data_at(*path)).to be_present
    end
  end

  context 'when requesting user permissions' do
    let(:query) do
      <<~QUERY
        query($first: Int!) {
          projects(membership: true, first: $first) {
            nodes {
              id
              userPermissions {
                readProject
                removeProject
              }
            }
          }
        }
      QUERY
    end

    before do
      stub_licensed_features(custom_roles: true)
    end

    it_behaves_like 'a working graphql query that returns data' do
      before do
        post_graphql(query, current_user: current_user, variables: { first: 1 })
      end

      it 'returns data', :aggregate_failures do
        expect(graphql_errors).to be_nil

        expect(graphql_data_at(:projects, :nodes, 0, :user_permissions)).to eq({
          'readProject' => true,
          'removeProject' => false
        })
      end
    end

    it 'avoids N+1 queries', :request_store do
      control = ActiveRecord::QueryRecorder.new do
        post_graphql(query, current_user: current_user, variables: { first: 1 })
      end

      expect do
        post_graphql(query, current_user: current_user, variables: { first: 5 })
      end.not_to exceed_query_limit(control)
    end
  end

  it_behaves_like 'projects graphql query with SAML session filtering'
end
