# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::AiGateway::Client, feature_category: :ai_abstraction_layer do
  include StubRequests

  let_it_be(:user) { create(:user) }
  let_it_be(:active_token) { create(:service_access_token, :active) }

  let(:expected_body) { { prompt: 'anything' } }
  let(:timeout) { described_class::DEFAULT_TIMEOUT }
  let(:service) { instance_double(CloudConnector::BaseAvailableServiceData, name: :test) }
  let(:enabled_by_namespace_ids) { [1, 2] }
  let(:enablement_type) { 'add_on' }
  let(:auth_response) do
    instance_double(Ai::UserAuthorizable::Response,
      namespace_ids: enabled_by_namespace_ids, enablement_type: enablement_type)
  end

  let(:expected_access_token) { active_token.token }
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

  let(:expected_response) { { "response" => "Response" } }
  let(:endpoint) { '/v1/test' }
  let(:url) { "#{::Gitlab::AiGateway.url}#{endpoint}" }
  let(:tracking_context) { { request_id: 'uuid', action: 'test' } }
  let(:response_body) { expected_response.to_json }
  let(:http_status) { 200 }
  let(:response_headers) { { 'Content-Type' => 'application/json' } }
  let(:logger) { instance_double('Gitlab::Llm::Logger') }

  before do
    allow(Gitlab::Llm::Logger).to receive(:build).and_return(logger)
    allow(logger).to receive(:conditional_info)
    allow(logger).to receive(:info)

    stub_request(:post, url)
      .with(
        body: expected_body,
        headers: expected_request_headers
      )
      .to_return(
        status: http_status,
        body: response_body,
        headers: response_headers
      )

    allow(CloudConnector::AvailableServices).to receive(:find_by_name).and_return(service)
    allow(service).to receive(:access_token).and_return(expected_access_token)
    allow(user).to receive(:allowed_to_use).and_return(auth_response)
  end

  subject(:ai_client) { described_class.new(user, service_name: :test, tracking_context: tracking_context) }

  describe '#complete' do
    subject(:complete) { ai_client.complete(url: url, body: expected_body) }

    context 'when measuring request success' do
      let(:client) { :ai_gateway }

      it_behaves_like 'measured Llm request'

      context 'when request raises an exception' do
        before do
          allow(Gitlab::HTTP).to receive(:post).and_raise(StandardError)
        end

        it_behaves_like 'measured Llm request with error', StandardError
      end

      context 'when request is retried' do
        let(:http_status) { 429 }

        before do
          allow(logger).to receive(:error)
          stub_const("Gitlab::Llm::Concerns::ExponentialBackoff::INITIAL_DELAY", 0.0)
        end

        it_behaves_like 'measured Llm request with error', Gitlab::Llm::Concerns::ExponentialBackoff::RateLimitError
      end

      context 'when request is retried once' do
        before do
          allow(logger).to receive(:error)
          stub_request(:post, url)
            .to_return(status: 429, body: '', headers: response_headers)
            .then.to_return(status: 200, body: response_body, headers: response_headers)

          stub_const("Gitlab::Llm::Concerns::ExponentialBackoff::INITIAL_DELAY", 0.0)
        end

        it_behaves_like 'measured Llm request'
      end
    end

    it 'returns response' do
      expect(Gitlab::HTTP).to receive(:post)
        .with(anything, hash_including(timeout: timeout))
        .and_call_original
      expect(complete.parsed_response).to eq(expected_response)
    end

    it 'logs request and response' do
      expect(Gitlab::HTTP).to receive(:post)
                                .with(anything, hash_including(timeout: timeout))
                                .and_call_original
      expect(complete).to be_a(HTTParty::Response)
      expect(complete.code).to eq(200)

      expect(logger).to have_received(:conditional_info)
        .with(user, a_hash_including(message: "Performing request to AI Gateway", body: expected_body, timeout: timeout,
          url: url, stream: false))
      expect(logger).to have_received(:conditional_info)
        .with(user, a_hash_including(message: "Received response from AI Gateway",
          response_from_llm: expected_response))
    end

    context 'when request is a 500 error with text body' do
      let(:http_status) { 500 }
      let(:response_headers) { nil }
      let(:response_body) { 'Internal server error' }

      it 'logs an error and returns nil' do
        expect(logger).to receive(:error)
          .with(a_hash_including(message: "Error response from AI Gateway", event_name: 'error_response_received',
            status: 500, body: nil))

        expect(complete).to be_nil
      end
    end

    context 'when request is a 500 error with JSON details' do
      let(:http_status) { 500 }
      let(:response_headers) { { 'Content-Type' => 'application/json' } }
      let(:response_body) { { 'detail' => 'System not ready' }.to_json }

      it 'logs an error and returns the detail' do
        expect(logger).to receive(:error)
          .with(a_hash_including(message: "Error response from AI Gateway", event_name: 'error_response_received',
            status: 500, body: 'System not ready'))

        expect(complete).to be_nil
      end
    end

    context 'when calling AI Gateway with Claude 2.1 model' do
      let(:model) { Gitlab::Llm::Concerns::AvailableModels::CLAUDE_3_5_SONNET }
      let(:options) { { model: model } }

      it 'returns expected response' do
        expect(Gitlab::HTTP).to receive(:post)
          .with(anything, hash_including(timeout: described_class::DEFAULT_TIMEOUT))
          .and_call_original
        expect(complete.parsed_response).to eq(expected_response)
      end
    end
  end

  describe '#complete_prompt' do
    subject(:complete_prompt) do
      ai_client.complete_prompt(
        base_url: ::Gitlab::AiGateway.url,
        prompt_name: 'test_prompt_name',
        inputs: { 'test' => 'Hello' },
        timeout: 10,
        prompt_version: '5.0.0',
        model_metadata: { name: 'mistral' }
      )
    end

    it 'completes with the correct values' do
      expected_body = {
        'inputs' => { 'test' => 'Hello' },
        'prompt_version' => '5.0.0',
        'model_metadata' => { name: 'mistral' }
      }
      expected_url = "#{::Gitlab::AiGateway.url}/v2/prompts/test_prompt_name"

      expect(ai_client).to receive(:complete).with(url: expected_url, body: expected_body, timeout: 10)

      complete_prompt
    end

    context 'when ai_prompts_v2 is disabled' do
      before do
        stub_feature_flags(ai_prompts_v2: false)
      end

      it 'completes with the correct values' do
        expected_body = {
          'inputs' => { 'test' => 'Hello' },
          'prompt_version' => '5.0.0',
          'model_metadata' => { name: 'mistral' }
        }
        expected_url = "#{::Gitlab::AiGateway.url}/v1/prompts/test_prompt_name"

        expect(ai_client).to receive(:complete).with(url: expected_url, body: expected_body, timeout: 10)

        complete_prompt
      end
    end
  end

  describe '#stream' do
    subject { ai_client.stream(url: url, body: expected_body) }

    context 'when streaming the request' do
      let(:response_body) { expected_response }

      context 'when response is successful' do
        let(:expected_response) { 'Hello' }

        it 'provides parsed streamed response' do
          expect { |b| ai_client.stream(url: url, body: expected_body, &b) }.to yield_with_args('Hello')
        end

        it 'returns response' do
          expect(Gitlab::HTTP).to receive(:post)
            .with(anything, hash_including(stream_body: true, timeout: timeout))
            .and_call_original

          expect(ai_client.stream(url: url, body: expected_body)).to eq("Hello")
        end

        context 'when setting a timeout' do
          it 'uses the timeout for the request' do
            expect(Gitlab::HTTP).to receive(:post)
              .with(anything, hash_including(stream_body: true, timeout: 50.seconds))
              .and_call_original

            ai_client.stream(url: url, body: expected_body, timeout: 50.seconds)
          end
        end

        context 'when url is passed as a parameter' do
          let(:url) { "http://127.0.0.1:5000" }

          it 'sends requests to this host instead' do
            ai_client.stream(url: url, body: expected_body)
          end
        end
      end

      context 'when response contains multiple events' do
        let(:expected_response) { "Hello World" }
        let(:success) do
          instance_double(HTTParty::Response,
            code: 200,
            success?: true,
            parsed_response: response_body,
            headers: response_headers,
            body: response_body
          )
        end

        before do
          allow(Gitlab::HTTP).to receive(:post).and_return(success)
            .and_yield("Hello").and_yield(" ").and_yield("World")
        end

        it 'provides parsed streamed response' do
          expect { |b| ai_client.stream(url: url, body: expected_body, &b) }
            .to yield_successive_args('Hello', ' ', 'World')
        end

        it 'returns response' do
          expect(ai_client.stream(url: url, body: expected_body)).to eq(expected_response)
        end
      end

      context 'when response is not successful' do
        let(:response_body) do
          { "detail" => [{ "msg" => "Input is invalid" }] }.to_json
        end

        let(:failure) do
          instance_double(HTTParty::Response,
            code: http_code,
            success?: false,
            headers: response_headers,
            body: response_body
          )
        end

        before do
          allow(ai_client).to receive(:perform_completion_request).and_yield(response_body).and_return(failure)
          allow(logger).to receive(:error)
          allow(failure).to receive(:forbidden?).and_return(forbidden_status)
        end

        context 'when there is problem with connection' do
          let(:http_code) { 400 }
          let(:forbidden_status) { false }

          it 'raises error' do
            expect { ai_client.stream(url: url, body: expected_body) }
              .to raise_error(Gitlab::Llm::AiGateway::Client::ConnectionError)

            expect(logger).to have_received(:error).with(a_hash_including(message: "Received error from AI gateway",
              response_from_llm: "Input is invalid"))
          end
        end

        context 'when instance do not have access to feature' do
          let(:http_code) { 403 }
          let(:forbidden_status) { true }

          it 'raises error' do
            expect { ai_client.stream(url: url, body: expected_body) }
              .to raise_error(Gitlab::AiGateway::ForbiddenError)

            expect(logger).to have_received(:error).with(a_hash_including(message: "Received error from AI gateway",
              response_from_llm: "Input is invalid"))
          end
        end
      end
    end
  end
end
