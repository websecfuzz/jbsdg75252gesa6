# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::ModelSelection::FetchModelDefinitionsService, feature_category: :"self-hosted_models" do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let(:cache_key) { described_class::RESPONSE_CACHE_NAME }
  let(:base_url) { 'http://0.0.0.0:5052' }
  let(:endpoint_url) { "#{base_url}/v1/models%2Fdefinitions" }
  let(:code_suggestions_service) { instance_double(::CloudConnector::BaseAvailableServiceData, name: :any_name) }
  let(:model_definitions) do
    {
      'models' => [
        { 'name' => 'Claude Sonnet', 'identifier' => 'claude_sonnet' }
      ],
      'unit_primitives' => [
        {
          'feature_setting' => 'duo_chat',
          'default_model' => 'claude-sonnet',
          'selectable_models' => %w[claude-sonnet],
          'beta_models' => []
        }
      ]
    }
  end

  let(:model_definitions_response) { model_definitions.to_json }

  let(:initialized_class) { described_class.new(user, model_selection_scope: group) }

  subject(:service) { initialized_class.execute }

  before do
    allow(::CloudConnector::AvailableServices).to receive(:find_by_name)
                                                    .with(:code_suggestions).and_return(code_suggestions_service)
    allow(::Gitlab::AiGateway).to receive(:url).and_return(base_url)
    allow(::Gitlab::AiGateway).to receive(:headers).with(user: user, service: code_suggestions_service)
  end

  describe '#model_selection_enabled?' do
    let(:feature_flag_state) { true }
    let(:duo_available) { true }

    subject(:method_call) { initialized_class.send(:model_selection_enabled?) }

    before do
      stub_feature_flags(ai_model_switching: feature_flag_state)
      stub_application_setting(duo_features_enabled: duo_available)
    end

    context 'when all criteria are met' do
      it 'returns true' do
        expect(method_call).to be(true)
      end
    end

    context 'when ai_model_selection feature flag is disabled' do
      let(:feature_flag_state) { false }

      it 'returns false' do
        expect(method_call).to be(false)
      end
    end

    context 'when application setting duo_features_enabled is disabled' do
      let(:duo_available) { false }

      it 'returns false' do
        expect(method_call).to be(false)
      end
    end
  end

  describe '#execute' do
    context 'when model switching is disabled' do
      before do
        allow(initialized_class).to receive(:model_selection_enabled?).and_return(false)
      end

      it 'returns nil' do
        expect(service).to be_nil
      end
    end

    context 'when model switching is enabled' do
      before do
        allow(initialized_class).to receive(:model_selection_enabled?).and_return(true)
      end

      context 'when response is cached' do
        let(:cached_data) { model_definitions }

        before do
          allow(Rails.cache).to receive(:exist?).with(cache_key).and_return(true)
          allow(Rails.cache).to receive(:fetch).with(cache_key).and_return(cached_data)
        end

        it 'returns cached response' do
          expect(service.payload).to eq(cached_data)
        end

        it 'does not make an HTTP request' do
          expect(Gitlab::HTTP).not_to receive(:get)
          service.payload
        end
      end

      context 'when response is not cached' do
        before do
          allow(Rails.cache).to receive(:exist?).with(cache_key).and_return(false)
        end

        context 'when API call is successful' do
          before do
            stub_request(:get, endpoint_url)
              .to_return(
                status: 200,
                body: model_definitions_response,
                headers: { 'Content-Type' => 'application/json' }
              )
          end

          it 'caches and returns the response' do
            expect(Rails.cache).to receive(:fetch).with(cache_key, expires_in: 1.hour)

            expect(service.payload).to include(model_definitions)
          end
        end

        context 'when API call returns forbidden error' do
          let(:error_message) { "Received error 401 from AI gateway when fetching model definitions" }

          before do
            stub_request(:get, endpoint_url)
              .to_return(
                status: 401,
                body: "{\"error\":\"No authorization header presented\"}",
                headers: { 'Content-Type' => 'application/json' }
              )
          end

          it 'logs the error and raises ForbiddenError' do
            expect(initialized_class).to receive(:log_error)

            expect(service.message).to eq(error_message)
            expect(service.payload).to eq({})
          end
        end
      end
    end
  end

  describe '#endpoint' do
    it 'returns the correct endpoint URL' do
      expect(initialized_class.send(:endpoint)).to eq(endpoint_url)
    end
  end

  describe '#service' do
    it 'returns the code suggestions service' do
      expect(initialized_class.send(:service)).to eq(code_suggestions_service)
    end
  end
end
