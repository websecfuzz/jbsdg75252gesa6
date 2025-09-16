# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Namespace.statuses', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group, :private) }
  let_it_be(:guest) { create(:user, guest_of: group) }

  let(:namespace) { group }
  let(:query) do
    <<~QUERY
    query {
      namespace(fullPath: "#{namespace.full_path}") {
        id
        statuses {
          nodes {
            id
            name
            iconName
            color
            description
            category
          }
        }
      }
    }
    QUERY
  end

  before do
    stub_licensed_features(work_item_status: true)
  end

  shared_examples 'returns statuses' do
    it 'returns statuses for a given namespace' do
      post_graphql(query, current_user: guest)

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_data_at(:namespace, :statuses, :nodes)).to match_array(expected_statuses)
    end
  end

  shared_examples 'does not return statuses' do
    it 'does not return statuses' do
      post_graphql(query, current_user: guest)

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_data_at(:namespace, :statuses, :nodes)).to be_blank
    end
  end

  context 'when user has permission to read statuses' do
    context 'with system-defined statuses' do
      let(:expected_statuses) do
        WorkItems::Statuses::SystemDefined::Status.all.map { |status| format_status(status) }
      end

      it_behaves_like 'returns statuses'
    end

    context 'with custom statuses' do
      let!(:expected_statuses) do
        create_list(:work_item_custom_status, 2, namespace: namespace).map { |status| format_status(status) }
      end

      it_behaves_like 'returns statuses'

      it 'avoids N+1 queries when fetching multiple statuses' do
        post_graphql(query, current_user: guest)

        control = ActiveRecord::QueryRecorder.new { post_graphql(query, current_user: guest) }

        create_list(:work_item_custom_status, 2, namespace: namespace)

        expect { post_graphql(query, current_user: guest) }.not_to exceed_query_limit(control)
      end
    end

    context 'when feature is not available' do
      before do
        stub_licensed_features(work_item_status: false)
      end

      it_behaves_like 'does not return statuses'
    end

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(work_item_status_feature_flag: false)
      end

      it_behaves_like 'does not return statuses'
    end
  end

  context 'when user does not have permission to read statuses' do
    let_it_be(:guest) { nil }

    it_behaves_like 'does not return statuses'
  end

  def format_status(status)
    {
      'id' => status.to_global_id.to_s,
      'name' => status.name,
      'iconName' => status.icon_name,
      'color' => status.color,
      'description' => status.description,
      'category' => status.category.to_s
    }
  end
end
