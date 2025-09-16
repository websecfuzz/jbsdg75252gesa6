# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::AiGateway::DocsClient, feature_category: :ai_abstraction_layer do
  include StubRequests

  let_it_be(:user) { create(:user) }

  let(:options) { {} }
  let(:expected_request_body) { default_body_params }

  let(:enabled_by_namespace_ids) { [1, 2] }
  let(:enablement_type) { 'add_on' }
  let(:auth_response) do
    instance_double(Ai::UserAuthorizable::Response,
      namespace_ids: enabled_by_namespace_ids, enablement_type: enablement_type)
  end

  let(:expected_feature_name) { :duo_chat }
  let(:expected_access_token) { '123' }
  let(:expected_gitlab_realm) { ::CloudConnector::GITLAB_REALM_SELF_MANAGED }
  let(:expected_gitlab_host_name) { Gitlab.config.gitlab.host }
  let(:expected_instance_id) { Gitlab::GlobalAnonymousId.instance_id }
  let(:expected_user_id) { Gitlab::GlobalAnonymousId.user_id(user) }
  let(:expected_request_headers) do
    {
      'X-Gitlab-Instance-Id' => expected_instance_id,
      'X-Gitlab-Global-User-Id' => expected_user_id,
      'X-Gitlab-Host-Name' => expected_gitlab_host_name,
      'X-Gitlab-Realm' => expected_gitlab_realm,
      'X-Gitlab-Authentication-Type' => 'oidc',
      'Authorization' => "Bearer #{expected_access_token}",
      "X-Gitlab-Feature-Enabled-By-Namespace-Ids" => [enabled_by_namespace_ids.join(',')],
      'X-Gitlab-Feature-Enablement-Type' => enablement_type,
      'Content-Type' => 'application/json',
      'X-Request-ID' => Labkit::Correlation::CorrelationId.current_or_new_id
    }
  end

  let(:default_body_params) do
    {
      type: described_class::DEFAULT_TYPE,
      metadata: {
        source: described_class::DEFAULT_SOURCE,
        version: Gitlab.version_info.to_s
      },
      payload: {
        query: "anything"
      }
    }
  end

  let(:expected_response) do
    { "foo" => "bar" }
  end

  let(:request_url) { "#{Gitlab::AiGateway.url}/v1/search/gitlab-docs" }
  let(:tracking_context) { { request_id: 'uuid', action: 'chat' } }
  let(:response_body) { expected_response.to_json }
  let(:http_status) { 200 }
  let(:response_headers) { { 'Content-Type' => 'application/json' } }

  before do
    service = instance_double(CloudConnector::BaseAvailableServiceData)
    allow(::CloudConnector::AvailableServices).to receive(:find_by_name).with(expected_feature_name).and_return(service)
    allow(service).to receive_messages(access_token: expected_access_token, name: expected_feature_name)
    allow(user).to receive(:allowed_to_use).and_return(auth_response)
  end

  describe '#search', :with_cloud_connector do
    before do
      stub_request(:post, request_url)
        .with(
          body: expected_request_body,
          headers: expected_request_headers
        )
        .to_return(
          status: http_status,
          body: response_body,
          headers: response_headers
        )
    end

    subject(:result) do
      described_class.new(user, tracking_context: tracking_context).search(query: 'anything', **options)
    end

    it 'returns response', quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/463071' do
      expect(Gitlab::HTTP).to receive(:post).with(
        anything,
        hash_including(timeout: described_class::DEFAULT_TIMEOUT)
      ).and_call_original
      expect(result.parsed_response).to eq(expected_response)
    end

    context 'when duo chat model is self-hosted' do
      let_it_be(:feature_setting) { create(:ai_feature_setting, feature: :duo_chat) }
      let(:expected_feature_name) { :duo_chat }

      it 'returns access token for duo_chat service' do
        expect(Gitlab::HTTP).to receive(:post).with(
          anything,
          hash_including(timeout: described_class::DEFAULT_TIMEOUT)
        ).and_call_original
        expect(result.parsed_response).to eq(expected_response)
      end
    end
  end
end
