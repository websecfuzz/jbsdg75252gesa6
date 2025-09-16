# frozen_string_literal: true

require "spec_helper"

RSpec.describe 'Subscriptions::AiCompletionResponse', feature_category: :duo_chat do
  include GraphqlHelpers
  include Graphql::Subscriptions::Notes::Helper

  let_it_be(:guest) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:resource) { create(:work_item, :task, project: project) }
  let_it_be(:agent) { create(:ai_agent, project: project) }
  let_it_be(:agent_version) { create(:ai_agent_version, agent: agent) }

  let_it_be(:external_issue) { create(:issue) }
  let_it_be(:external_issue_url) do
    project_issue_url(external_issue.project, external_issue)
  end

  let_it_be(:thread) { create(:ai_conversation_thread) }

  let(:current_user) { nil }
  let(:requested_user) { current_user }
  let(:ai_completion_response) { graphql_dig_at(graphql_data(response[:result]), :ai_completion_response) }
  let(:request_id) { 'uuid' }
  let(:content) { "Some AI response #{external_issue_url}+" }
  let(:extras) { { sources: [{ source_url: 'foo', source_some_metadata: 'bar' }] }.deep_stringify_keys }
  let(:params) do
    {
      user_id: current_user&.to_gid,
      resource_id: resource.to_gid,
      agent_version_id: agent_version.to_gid,
      client_subscription_id: 'id'
    }
  end

  let(:content_html) do
    "<p dir=\"auto\">Some AI response " \
      "<a href=\"#{external_issue_url}+\">#{external_issue_url}+</a></p>"
  end

  let(:subscription_query) do
    <<~SUBSCRIPTION
      subscription {
        aiCompletionResponse(#{subscription_arguments}) {
          content
          contentHtml
          role
          requestId
          errors
          chunkId
          threadId
          extras {
            sources
          }
        }
      }
    SUBSCRIPTION
  end

  let(:subscribe) do
    mock_channel = Graphql::Subscriptions::ActionCable::MockActionCable.get_mock_channel

    GitlabSchema.execute(subscription_query, context: { current_user: current_user, channel: mock_channel })

    mock_channel
  end

  let(:subscription_arguments) do
    build_arguments(params.merge(user_id: requested_user&.to_gid))
  end

  before do
    stub_const('GitlabSchema', Graphql::Subscriptions::ActionCable::MockGitlabSchema)
    Graphql::Subscriptions::ActionCable::MockActionCable.clear_mocks
    project.add_guest(guest)
  end

  subject(:response) do
    subscription_response do
      data = {
        request_id: request_id,
        content: content,
        role: ::Gitlab::Llm::AiMessage::ROLE_ASSISTANT,
        errors: [],
        extras: extras,
        thread: thread,
        chunk_id: nil
      }.with_indifferent_access

      ::GitlabSchema.subscriptions.trigger(:ai_completion_response, params, data)
    end
  end

  shared_examples 'on success' do
    it 'receives data' do
      expect(ai_completion_response['content']).to eq(content)
      expect(ai_completion_response['contentHtml']).to eq_no_sourcepos(content_html)
      expect(ai_completion_response['role']).to eq('ASSISTANT')
      expect(ai_completion_response['requestId']).to eq(request_id)
      expect(ai_completion_response['errors']).to eq([])
      expect(ai_completion_response['chunkId']).to eq(nil)
      expect(ai_completion_response['threadId']).to eq(thread.to_global_id.to_s)
      expect(ai_completion_response['extras']).to eq(extras)
    end
  end

  context 'when user is nil' do
    it 'does not receive any data' do
      expect(response).to be_nil
    end
  end

  context 'when unauthorized user requests an authorized one' do
    let(:current_user) { nil }
    let(:requested_user) { guest }

    it 'does not receive any data' do
      expect(response).to be_nil
    end
  end

  context 'when user is unauthorized' do
    let(:current_user) { create(:user) }

    it 'does not receive any data' do
      expect(response).to be_nil
    end
  end

  context 'when user is authorized' do
    let(:current_user) { guest }

    context 'when client_subscription_id is set' do
      it_behaves_like 'on success'
    end

    context 'when client_subscription_id is null' do
      let(:params) { { user_id: current_user.to_gid, resource_id: resource.to_gid, client_subscription_id: nil } }

      it_behaves_like 'on success'
    end

    context 'when client_subscription_id is not part of the subscription' do
      let(:params) { { user_id: current_user.to_gid, resource_id: resource.to_gid } }

      it_behaves_like 'on success'
    end

    context 'when resource_id is null' do
      let(:params) { { user_id: current_user.to_gid, resource_id: nil } }

      it_behaves_like 'on success'
    end

    context 'when resource_id is not part of the subscription' do
      let(:params) { { user_id: current_user.to_gid } }

      it_behaves_like 'on success'
    end

    context 'when agent_version_id is null' do
      let(:params) { { user_id: current_user.to_gid, agent_version_id: nil } }

      it_behaves_like 'on success'
    end

    context 'when ai_action is null' do
      let(:params) { { user_id: current_user.to_gid, ai_action: nil } }

      it_behaves_like 'on success'
    end

    context 'when ai_action is set' do
      let(:params) { { user_id: current_user.to_gid, ai_action: 'chat' } }
      let(:subscription_arguments) { "userId: \"#{current_user.to_gid}\", aiAction: CHAT" }

      it_behaves_like 'on success'
    end
  end

  def build_arguments(params)
    params.reduce([]) do |acc, (k, v)|
      acc << "#{k.to_s.camelize(:lower)}: #{v.nil? ? 'null' : "\"#{v}\""}"
    end.join(",")
  end
end
