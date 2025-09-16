# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Namespace.lifecycles', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group, :private) }
  let_it_be(:guest) { create(:user, guest_of: group) }

  let(:namespace) { group }
  let(:query) do
    <<~QUERY
    query {
      namespace(fullPath: "#{namespace.full_path}") {
        id
        lifecycles {
          nodes {
            id
            name
            defaultOpenStatus {
              id
            }
            defaultClosedStatus {
              id
            }
            defaultDuplicateStatus {
              id
            }
            workItemTypes {
              id
            }
          }
        }
      }
    }
    QUERY
  end

  before do
    stub_licensed_features(work_item_status: true)
  end

  shared_examples 'returns lifecycles' do
    it 'returns lifecycles for a given namespace' do
      post_graphql(query, current_user: guest)

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_data_at(:namespace, :lifecycles, :nodes)).to match_array(expected_lifecycles)
    end
  end

  context 'when user has permission to read lifecycles' do
    context 'with system-defined lifecycles' do
      let(:expected_lifecycles) do
        WorkItems::Statuses::SystemDefined::Lifecycle.all.map { |lifecycle| format_lifecycle(lifecycle) }
      end

      it_behaves_like 'returns lifecycles'
    end

    context 'with custom lifecycles' do
      let!(:custom_lifecycle) { create(:work_item_custom_lifecycle, namespace: namespace) }
      let(:expected_lifecycles) { [format_lifecycle(custom_lifecycle)] }

      it_behaves_like 'returns lifecycles'

      it 'avoids N+1 queries when fetching multiple lifecycles' do
        post_graphql(query, current_user: guest)

        control = ActiveRecord::QueryRecorder.new { post_graphql(query, current_user: guest) }

        create_list(:work_item_custom_lifecycle, 2, namespace: namespace)

        expect { post_graphql(query, current_user: guest) }.not_to exceed_query_limit(control)
      end
    end

    context 'when feature is not available' do
      before do
        stub_licensed_features(work_item_status: false)
      end

      it 'does not return lifecycles' do
        post_graphql(query, current_user: guest)

        expect(response).to have_gitlab_http_status(:ok)
        expect(graphql_data_at(:namespace, :lifecycles, :nodes)).to be_blank
      end
    end
  end

  context 'when user does not have permission to read lifecycles' do
    it 'does not return lifecycles' do
      post_graphql(query, current_user: create(:user))

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_data_at(:namespace, :lifecycles, :nodes)).to be_blank
    end
  end

  def format_lifecycle(lifecycle)
    {
      'id' => lifecycle.to_global_id.to_s,
      'name' => lifecycle.name,
      'defaultOpenStatus' => {
        'id' => lifecycle.default_open_status.to_global_id.to_s
      },
      'defaultClosedStatus' => {
        'id' => lifecycle.default_closed_status.to_global_id.to_s
      },
      'defaultDuplicateStatus' => {
        'id' => lifecycle.default_duplicate_status.to_global_id.to_s
      },
      'workItemTypes' => lifecycle.work_item_types.map do |type|
        {
          'id' => type.to_global_id.to_s
        }
      end
    }
  end
end
