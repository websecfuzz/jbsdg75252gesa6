# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::InsightsController, feature_category: :value_stream_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user, developer_of: group) }

  let(:query_params) do
    {
      type: 'bar',
      query: {
        data_source: 'issuables',
        params: {
          issuable_type: 'issue',
          collection_labels: ['bug']
        }
      }
    }
  end

  before do
    stub_licensed_features(insights: true, dora4_analytics: true)

    login_as(user)
  end

  describe 'GET #show' do
    it_behaves_like 'contribution analytics charts configuration' do
      let_it_be(:insights_entity) { project }

      def run_request
        get namespace_project_insights_path(
          namespace_id: group,
          project_id: project,
          format: :json
        )
      end
    end
  end

  describe 'POST #query' do
    def run_request
      post query_namespace_project_insights_path(
        namespace_id: group,
        project_id: project,
        params: query_params,
        format: :json
      )
    end

    it 'succeeds' do
      run_request

      expect(response).to have_gitlab_http_status(:ok)
    end

    context 'when statement timeout happens' do
      it 'returns error response' do
        expect_next_instance_of(IssuesFinder) do |instance|
          expect(instance).to receive(:execute).and_raise(ActiveRecord::QueryCanceled)
        end

        run_request

        expect(response).to have_gitlab_http_status(:unprocessable_entity)

        expect(json_response['message']).to include('Try lowering the period_limit setting')
      end
    end
  end
end
