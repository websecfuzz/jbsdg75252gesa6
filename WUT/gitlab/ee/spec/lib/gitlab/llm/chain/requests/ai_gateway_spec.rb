# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Requests::AiGateway, feature_category: :duo_chat do
  let_it_be(:user) { build(:user) }
  let(:tracking_context) { { action: 'chat', request_id: 'uuid' } }

  subject(:instance) { described_class.new(user, tracking_context: tracking_context) }

  describe 'initializer' do
    it 'initializes the AI Gateway client' do
      expect(instance.ai_client.class).to eq(::Gitlab::Llm::AiGateway::Client)
    end

    context 'when alternative service name is passed' do
      it 'creates ai gateway client with different service name' do
        expect(::Gitlab::Llm::AiGateway::Client).to receive(:new).with(
          user,
          service_name: :alternative,
          tracking_context: tracking_context
        )

        described_class.new(user, service_name: :alternative, tracking_context: tracking_context)
      end
    end

    context 'when duo chat is self-hosted' do
      let_it_be(:feature_setting) { create(:ai_feature_setting, feature: :duo_chat, provider: :self_hosted) }

      it 'creates ai gateway client with duo_chat service name' do
        expect(::Gitlab::Llm::AiGateway::Client).to receive(:new).with(
          user,
          service_name: :duo_chat,
          tracking_context: tracking_context
        )

        described_class.new(user, service_name: :duo_chat, tracking_context: tracking_context)
      end
    end
  end

  # rubocop:disable RSpec/MultipleMemoizedHelpers -- helpers are needed
  describe '#request' do
    let(:logger) { instance_double(Gitlab::Llm::Logger) }
    let(:ai_client) { double }
    let(:endpoint) { described_class::ENDPOINT }
    let(:url) { "#{::Gitlab::AiGateway.url}#{endpoint}" }
    let(:model) { nil }
    let(:expected_model) { described_class::CLAUDE_3_5_SONNET }
    let(:provider) { :anthropic }
    let(:params) do
      {
        max_tokens_to_sample: described_class::DEFAULT_MAX_TOKENS,
        stop_sequences: ["\n\nHuman", "Observation:"],
        temperature: 0.1
      }
    end

    let(:prompt_version) { "2.0.0" }
    let(:user_prompt) { "some user request" }
    let(:options) { { model: model } }
    let(:prompt) { { prompt: user_prompt, options: options } }
    let(:unit_primitive) { nil }
    let(:payload) do
      {
        content: user_prompt,
        provider: provider,
        model: expected_model,
        params: params
      }
    end

    let(:body) do
      {
        prompt_components: [{
          type: described_class::DEFAULT_TYPE,
          metadata: {
            source: described_class::DEFAULT_SOURCE,
            version: Gitlab.version_info.to_s
          },
          payload: payload
        }],
        stream: true
      }
    end

    let(:response) { 'Hello World' }

    subject(:request) { instance.request(prompt, unit_primitive: unit_primitive) }

    before do
      allow(Gitlab::Llm::Logger).to receive(:build).and_return(logger)
      allow(logger).to receive(:conditional_info)
      allow(instance).to receive(:ai_client).and_return(ai_client)
      stub_feature_flags(ai_model_switching: false)
    end

    shared_examples 'performing request to the AI Gateway' do
      it 'returns the response from AI Gateway' do
        expect(ai_client).to receive(:stream).with(url: url, body: body).and_return(response)

        expect(request).to eq(response)
      end
    end

    it 'logs the request and response' do
      expect(ai_client).to receive(:stream).with(url: url, body: body).and_return(response)
      expect(logger).to receive(:conditional_info).with(
        user,
        a_hash_including(
          message: "Made request to AI Client",
          klass: described_class.to_s,
          prompt: user_prompt,
          response_from_llm: response
        ))

      request
    end

    it 'calls the AI Gateway streaming endpoint and yields response without stripping it' do
      expect(ai_client).to receive(:stream).with(url: url, body: body).and_yield(response)
        .and_return(response)

      expect { |b| instance.request(prompt, &b) }.to yield_with_args(response)
    end

    it_behaves_like 'performing request to the AI Gateway'

    it_behaves_like 'tracks events for AI requests', 4, 2, klass: 'Gitlab::Llm::Anthropic::Client' do
      before do
        allow(ai_client).to receive(:stream).with(url: url, body: body).and_return(response)
      end
    end

    context 'when additional params are passed in as options' do
      let(:options) do
        { temperature: 1, stop_sequences: %W[\n\Foo Bar:], max_tokens_to_sample: 1024, disallowed_param: 1, topP: 1 }
      end

      let(:params) do
        {
          max_tokens_to_sample: 1024,
          stop_sequences: ["\n\Foo", "Bar:"],
          temperature: 1
        }
      end

      it_behaves_like 'performing request to the AI Gateway'
    end

    context 'when unit primitive is passed with no corresponding feature setting' do
      let(:endpoint) { "#{described_class::BASE_ENDPOINT}/test" }
      let(:unit_primitive) { :test }

      it_behaves_like 'performing request to the AI Gateway'
    end

    context 'when other model is passed' do
      let(:model) { ::Gitlab::Llm::Concerns::AvailableModels::VERTEX_MODEL_CHAT }
      let(:expected_model) { model }
      let(:provider) { :vertex }
      let(:params) { { temperature: 0.1 } } # This checks that non-vertex params lie `stop_sequence` are filtered out

      it_behaves_like 'performing request to the AI Gateway'
      it_behaves_like 'tracks events for AI requests', 4, 2, klass: 'Gitlab::Llm::VertexAi::Client' do
        before do
          allow(ai_client).to receive(:stream).with(url: url, body: body).and_return(response)
        end
      end
    end

    context 'when invalid model is passed' do
      let(:model) { 'test' }

      it 'returns nothing' do
        expect(ai_client).not_to receive(:stream).with(url: url, body: anything)

        expect(request).to eq(nil)
      end
    end

    context "when no model is provided" do
      let(:model) { nil }
      let(:expected_model) { ::Gitlab::Llm::Concerns::AvailableModels::CLAUDE_3_5_SONNET }
      let(:expected_response) { "Hello World" }

      it "calls ai gateway client with claude 3.5 sonnet model defaulted" do
        expect(ai_client).to receive(:stream).with(
          hash_including(
            body: hash_including(
              prompt_components: array_including(
                hash_including(
                  payload: hash_including(model: expected_model)
                )
              )
            )
          )
        )

        request

        expect(response).to eq(expected_response)
      end
    end

    context 'when user is using a Self-hosted model' do
      let!(:ai_feature) { create(:ai_feature_setting, self_hosted_model: self_hosted_model, feature: :duo_chat) }
      let!(:self_hosted_model) { create(:ai_self_hosted_model, api_token: 'test_token') }
      let(:expected_model) { self_hosted_model.model.to_s }

      let(:payload) do
        {
          content: user_prompt,
          provider: :litellm,
          model: expected_model,
          model_endpoint: self_hosted_model.endpoint,
          model_api_key: self_hosted_model.api_token,
          model_identifier: "provider/some-model",
          params: params
        }
      end

      it_behaves_like 'performing request to the AI Gateway'
    end

    context 'when user amazon q is connected' do
      let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_amazon_q) }

      let(:unit_primitive) { :explain_code }
      let(:endpoint) { "#{described_class::BASE_PROMPTS_CHAT_ENDPOINT}/#{unit_primitive}" }
      let(:inputs) { { field: :test_field } }

      let(:options) do
        {
          use_ai_gateway_agent_prompt: true,
          inputs: inputs,
          prompt_version: '2.0.0'
        }
      end

      let(:body) do
        {
          stream: true,
          inputs: inputs,
          model_metadata: {
            provider: :amazon_q,
            name: :amazon_q,
            role_arn: 'role-arn'
          },
          prompt_version: "^1.0.0"
        }
      end

      before do
        stub_licensed_features(amazon_q: true)
        Ai::Setting.instance.update!(amazon_q_ready: true, amazon_q_role_arn: 'role-arn')
      end

      it_behaves_like 'performing request to the AI Gateway'
    end

    context 'when request is sent to chat tools implemented via agents' do
      let_it_be(:feature_setting) { create(:ai_feature_setting, feature: :duo_chat, provider: :self_hosted) }

      let(:options) do
        {
          use_ai_gateway_agent_prompt: true,
          inputs: inputs,
          prompt_version: prompt_version
        }
      end

      let(:body) do
        {
          stream: true,
          inputs: inputs,
          model_metadata: model_metadata,
          prompt_version: "^1.0.0"
        }
      end

      let(:prompt) { { prompt: user_prompt, options: options } }
      let(:inputs) { { field: :test_field } }

      let(:unit_primitive) { :test }
      let(:endpoint) { "#{described_class::BASE_PROMPTS_CHAT_ENDPOINT}/#{unit_primitive}" }
      let(:model_metadata) do
        { api_key: "token", endpoint: "http://localhost:11434/v1", name: "mistral", provider: :openai, identifier: 'provider/some-model' }
      end

      before_all do
        create(:cloud_connector_keys)
      end

      context 'with a unit primitive corresponding a feature setting' do
        let_it_be(:model_api_key) { 'explain_code_token_model' }
        let_it_be(:model_identifier) { 'provider/some-cool-model' }
        let_it_be(:model_endpoint) { 'http://example.explain_code.dev' }
        let_it_be(:self_hosted_model) do
          create(:ai_self_hosted_model, name: 'explain_code', endpoint: model_endpoint, api_token: model_api_key,
            identifier: model_identifier)
        end

        let_it_be(:self_hosted_sub_feature_setting) do
          create(
            :ai_feature_setting,
            feature: :duo_chat_explain_code,
            provider: :self_hosted,
            self_hosted_model: self_hosted_model
          )
        end

        let(:sub_feature_setting) { self_hosted_sub_feature_setting }

        let(:unit_primitive) { :explain_code }

        let(:endpoint) { "#{described_class::BASE_PROMPTS_CHAT_ENDPOINT}/#{unit_primitive}" }

        let(:model_metadata) do
          { api_key: model_api_key, endpoint: model_endpoint, name: "mistral", provider: :openai,
            identifier: model_identifier }
        end

        it 'fetches the right prompt version' do
          expect(Gitlab::Llm::PromptVersions).to receive(:version_for_prompt).with('chat/explain_code', 'mistral')
                                                                             .and_call_original

          expect(ai_client).to receive(:stream).with(url: url, body: body).and_return(response)
          expect(request).to eq(response)
        end

        context 'if feature setting is not set for self_hosted' do
          let(:unit_primitive) { :fix_code }

          let!(:sub_feature_setting) do
            create(
              :ai_feature_setting,
              feature: :duo_chat_fix_code,
              provider: :vendored,
              self_hosted_model: self_hosted_model
            )
          end

          let(:body) do
            {
              stream: true,
              inputs: inputs,
              prompt_version: "2.0.0"
            }
          end

          it 'uses the passed prompt version' do
            expect(ai_client).to receive(:stream).with(url: url, body: body).and_return(response)
            expect(request).to eq(response)
          end
        end
      end
    end

    context 'when root_namespace is passed' do
      let_it_be(:root_namespace) { create(:group) }
      let(:tracking_context) { { action: 'chat', request_id: 'uuid' } }
      let(:user_prompt) { "Some prompt" }
      let(:response) { 'response from llm' }
      let(:logger) { instance_double(Gitlab::Llm::Logger) }
      let(:ai_client) { double }

      before do
        allow(Gitlab::Llm::Logger).to receive(:build).and_return(logger)
        allow(logger).to receive(:conditional_info)
        allow_next_instance_of(described_class) do |instance|
          allow(instance).to receive(:ai_client).and_return(ai_client)
        end
      end

      shared_examples_for 'sends a request with identifier and feature_setting' do
        specify do
          url = "#{::Gitlab::AiGateway.url}#{described_class::BASE_ENDPOINT}/#{unit_primitive}"

          expect(ai_client).to receive(:stream).with(
            hash_including(
              url: url,
              body: hash_including(
                prompt_components: array_including(
                  hash_including(payload: hash_including(
                    provider: "gitlab",
                    feature_setting: 'duo_chat_explain_code',
                    identifier: model_ref
                  ))
                )
              )
            )
          ).and_return(response)

          gateway = described_class.new(user, root_namespace: root_namespace, tracking_context: tracking_context)
          expect(gateway.request(prompt, unit_primitive: unit_primitive)).to eq(response)
        end
      end

      context 'when model switching is enabled and model is selected' do
        let(:unit_primitive) { :explain_code }
        let(:model_ref) { 'claude-3-7-sonnet-20250219' }
        let(:prompt) { { prompt: user_prompt, options: {} } }

        before do
          stub_feature_flags(ai_model_switching: true)
          create(:ai_namespace_feature_setting, namespace: root_namespace,
            feature: :"duo_chat_#{unit_primitive}", offered_model_ref: model_ref)
        end

        it_behaves_like 'sends a request with identifier and feature_setting'
      end

      context 'when model switching is enabled and a model is explicitly selected as `GitLab Default`' do
        let(:unit_primitive) { :explain_code }
        let(:prompt) { { prompt: user_prompt, options: {} } }
        let(:model_ref) { nil }

        before do
          stub_feature_flags(ai_model_switching: true)
          # When `offered_model_ref` is set to nil, it is considered by AI Gateway as the
          # GitLab default model.
          create(:ai_namespace_feature_setting, namespace: root_namespace,
            feature: :"duo_chat_#{unit_primitive}", offered_model_ref: model_ref)
        end

        it_behaves_like 'sends a request with identifier and feature_setting'
      end

      context 'when model switching is enabled, but a model is explicitly not selected ' \
        '(ie, it should behave like the default GitLab model is selected)' do
        let(:unit_primitive) { :explain_code }
        let(:prompt) { { prompt: user_prompt, options: {} } }
        let(:model_ref) { nil }

        before do
          stub_feature_flags(ai_model_switching: true)
        end

        it_behaves_like 'sends a request with identifier and feature_setting'
      end

      context 'when using agent prompt with model switching' do
        let(:unit_primitive) { :explain_code }
        let(:model_ref) { 'claude-3-7-sonnet-20250219' }
        let(:prompt) do
          {
            options: {
              use_ai_gateway_agent_prompt: true,
              inputs: { a: 1 }
            }
          }
        end

        before do
          stub_feature_flags(ai_model_switching: true)
          create(:ai_namespace_feature_setting, namespace: root_namespace,
            feature: :"duo_chat_#{unit_primitive}", offered_model_ref: model_ref)
        end

        it 'sends model_metadata with identifier and feature_setting' do
          url = "#{::Gitlab::AiGateway.url}#{described_class::BASE_PROMPTS_CHAT_ENDPOINT}/#{unit_primitive}"

          expect(ai_client).to receive(:stream).with(
            hash_including(
              url: url,
              body: hash_including(
                inputs: { a: 1 },
                model_metadata: {
                  provider: 'gitlab',
                  feature_setting: 'duo_chat_explain_code',
                  identifier: model_ref
                },
                prompt_version: a_kind_of(String)
              )
            )
          ).and_return(response)

          gateway = described_class.new(user, root_namespace: root_namespace, tracking_context: tracking_context)
          expect(gateway.request(prompt, unit_primitive: unit_primitive)).to eq(response)
        end
      end

      context 'when model switching is disabled' do
        let(:unit_primitive) { nil }
        let(:prompt) { { prompt: user_prompt, options: {} } }

        before do
          stub_feature_flags(ai_model_switching: false)
        end

        it 'uses default classic model' do
          url = "#{::Gitlab::AiGateway.url}#{described_class::ENDPOINT}"

          expect(ai_client).to receive(:stream).with(
            hash_including(
              url: url,
              body: hash_including(
                prompt_components: array_including(
                  hash_including(payload: hash_including(
                    provider: :anthropic,
                    model: described_class::CLAUDE_3_5_SONNET
                  ))
                )
              )
            )
          ).and_return(response)

          gateway = described_class.new(user, root_namespace: root_namespace, tracking_context: tracking_context)
          expect(gateway.request(prompt, unit_primitive: unit_primitive)).to eq(response)
        end
      end

      context 'when root_namespace is not root' do
        let(:subgroup) { create(:group, parent: root_namespace) }
        let(:unit_primitive) { 'write_tests' }
        let(:prompt) { { prompt: user_prompt, options: {} } }

        before do
          stub_feature_flags(ai_model_switching: true)
        end

        it 'ignores model switching' do
          url = "#{::Gitlab::AiGateway.url}/v1/chat/write_tests"

          expect(ai_client).to receive(:stream).with(
            hash_including(
              url: url,
              body: hash_including(
                prompt_components: array_including(
                  hash_including(payload: hash_including(
                    provider: :anthropic,
                    model: 'claude-3-5-sonnet-20240620'
                  ))
                )
              )
            )
          ).and_return(response)

          gateway = described_class.new(user, root_namespace: subgroup, tracking_context: tracking_context)
          expect(gateway.request(prompt, unit_primitive: unit_primitive)).to eq(response)
        end
      end
    end
  end
  # rubocop:enable RSpec/MultipleMemoizedHelpers
end
