# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Ai::Llm::GitCommand, :saas, feature_category: :code_review_workflow do
  let_it_be(:current_user) { create :user }

  let(:url) { '/ai/llm/git_command' }
  let(:input_params) { { prompt: 'list 10 commit titles' } }
  let(:make_request) { post api(url, current_user), params: input_params }

  before do
    stub_licensed_features(glab_ask_git_command: true)
    stub_ee_application_setting(should_check_namespace_plan: true)
  end

  describe 'POST /ai/llm/git_command', :saas, :use_clean_rails_redis_caching do
    let_it_be(:group, refind: true) { create(:group_with_plan, plan: :ultimate_plan) }

    before_all do
      group.add_developer(current_user)
    end

    include_context 'with ai features enabled for group'

    context 'when the endpoint is called too many times' do
      it 'returns too many requests response' do
        expect(Gitlab::ApplicationRateLimiter).to(
          receive(:throttled?).with(:ai_action, scope: [current_user]).and_return(true)
        )

        make_request

        expect(response).to have_gitlab_http_status(:too_many_requests)
      end
    end

    context 'when allowed to use the service' do
      let(:service_response) do
        ServiceResponse.new(
          status: :success,
          payload: {
            predictions: [
              {
                candidates: [
                  {
                    content: 'interesting AI content'
                  }
                ]
              }
            ]
          }
        )
      end

      it 'responds with Workhorse send-url headers' do
        allow(::Llm::GitCommandService)
          .to receive_message_chain(:new, :execute)
          .and_return(service_response)

        make_request

        expect(response.body).to include("\"candidates\":[{\"content\":\"interesting AI content\"")
        expect(response).to have_gitlab_http_status(:success)
      end
    end
  end
end
