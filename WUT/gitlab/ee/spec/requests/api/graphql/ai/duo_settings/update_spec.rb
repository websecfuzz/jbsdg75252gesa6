# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Updating an AI Feature setting', feature_category: :"self-hosted_models" do
  include GraphqlHelpers

  let_it_be_with_reload(:current_user) { create(:admin) }
  let_it_be(:license) { create(:license, plan: License::ULTIMATE_PLAN) }
  let_it_be_with_reload(:add_on_purchase) do
    create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :active, :self_managed)
  end

  let!(:duo_settings) { create(:ai_settings, duo_core_features_enabled: false) }

  let(:mutation_name) { :duo_settings_update }
  let(:mutation_params) { { ai_gateway_url: "http://new-ai-gateway-url", duo_core_features_enabled: true } }

  let(:mutation) { graphql_mutation(mutation_name, mutation_params) }

  subject(:request) { post_graphql_mutation(mutation, current_user: current_user) }

  describe '#resolve' do
    shared_examples 'performs the right authorization for duo_core_features_enabled' do
      it 'performs the right authorization for duo_core_features_enabled correctly' do
        allow(Ability).to receive(:allowed?).and_call_original
        expect(Ability).to receive(:allowed?).with(current_user, :manage_duo_core_settings)

        request
      end
    end

    context 'when the user does not have write access' do
      context 'when attempting to update ai_gateway_url' do
        let(:current_user) { create(:user) }
        let(:mutation_params) { { ai_gateway_url: "http://new-ai-gateway-url" } }

        it_behaves_like 'performs the right authorization'

        it 'returns an error about the missing permission' do
          request

          expect(graphql_errors).to be_present
          expect(graphql_errors.pluck('message')).to match_array(
            "You don't have permission to update the setting ai_gateway_url."
          )
        end
      end

      context 'when attempting to update duo_core_features_enabled' do
        let(:mutation_params) { { duo_core_features_enabled: true } }

        before do
          stub_licensed_features(code_suggestions: false, ai_chat: false)
        end

        it_behaves_like 'performs the right authorization for duo_core_features_enabled'

        it 'returns an error about the missing permission' do
          request

          expect(graphql_errors).to be_present
          expect(graphql_errors.pluck('message')).to match_array(
            "You don't have permission to update the setting duo_core_features_enabled."
          )
        end
      end
    end

    context 'when the user has write access' do
      it_behaves_like 'performs the right authorization'
      it_behaves_like 'performs the right authorization for duo_core_features_enabled'

      context 'when there are errors' do
        context 'when there is an error for ai_gateway_url' do
          let(:mutation_params) { { ai_gateway_url: "foobar" } }

          it 'returns an error' do
            request

            result = json_response['data']['duoSettingsUpdate']

            expect(result['errors']).to match_array(
              ["Ai gateway url Only allowed schemes are http, https"]
            )

            expect { duo_settings.reload }.not_to change { duo_settings }
          end

          it 'returns the existing ai setting values' do
            request

            result = json_response['data']['duoSettingsUpdate']

            expect(result['duoSettings']).to include(
              'aiGatewayUrl' => 'http://0.0.0.0:5052',
              'duoCoreFeaturesEnabled' => false
            )
          end
        end

        context 'when there is an error for duoCoreFeaturesEnabled' do
          let(:mutation_params) { { duoCoreFeaturesEnabled: nil } }

          it 'returns an error' do
            request

            result = json_response

            expect(result['data']['duoSettingsUpdate']).to be_nil
            expect(result['errors'].count).to eq(1)
            expect(result['errors'].first['message']).to eq("duoCoreFeaturesEnabled can't be null")

            expect { duo_settings.reload }.not_to change { duo_settings }
          end
        end
      end

      context 'when there are no errors' do
        it 'updates Duo settings' do
          request

          result = json_response['data']['duoSettingsUpdate']

          expect(result['duoSettings']).to include(
            "aiGatewayUrl" => "http://new-ai-gateway-url",
            "duoCoreFeaturesEnabled" => true
          )
          expect(result['errors']).to eq([])

          expect { duo_settings.reload }.to change { duo_settings.ai_gateway_url }.to("http://new-ai-gateway-url")
            .and change { duo_settings.duo_core_features_enabled }.to(true)
        end

        context 'when ai_gateway_url arg is a blank string' do
          let(:mutation_params) { { ai_gateway_url: "" } }

          it 'coerces it to nil' do # an empty string will cause the Duo healthcheck to error
            request

            result = json_response['data']['duoSettingsUpdate']

            expect(result['duoSettings']).to include("aiGatewayUrl" => nil)
            expect(result['errors']).to eq([])

            expect { duo_settings.reload }.to change { duo_settings.ai_gateway_url }.to(nil)
          end
        end

        context 'when ai_gateway_url has a trailing /' do
          let(:mutation_params) { { ai_gateway_url: "http://new-ai-gateway-url/" } }

          it 'remove the trailing slash before saving' do # an empty string will cause the Duo healthcheck to error
            request

            result = json_response['data']['duoSettingsUpdate']

            expect(result['duoSettings']).to include("aiGatewayUrl" => "http://new-ai-gateway-url")
            expect(result['errors']).to eq([])

            expect { duo_settings.reload }.to change { duo_settings.ai_gateway_url }.to("http://new-ai-gateway-url")
          end
        end

        context 'when the user has no read permission for ai_gateway_url' do
          let(:mutation_params) { { duo_core_features_enabled: true } }

          before do
            add_on_purchase.update!(expires_on: Date.yesterday)
          end

          it 'updates the duo_core_features_enabled setting and returns nil for ai_gateway_url' do
            request

            result = json_response['data']['duoSettingsUpdate']

            expect(result['duoSettings']).to include(
              'aiGatewayUrl' => nil,
              'duoCoreFeaturesEnabled' => true
            )
            expect(result['errors']).to eq([])

            expect { duo_settings.reload }.to change { duo_settings.duo_core_features_enabled }.to(true)
              .and not_change { duo_settings.ai_gateway_url }
          end
        end

        context 'when the user has no read permission for duo_core_features_enabled' do
          let(:mutation_params) { { ai_gateway_url: "http://new-ai-gateway-url" } }

          before do
            stub_licensed_features(code_suggestions: false, ai_chat: false)
          end

          it 'updates the ai_gateway_url setting and returns nil for duo_core_features_enabled' do
            request

            result = json_response['data']['duoSettingsUpdate']

            expect(result['duoSettings']).to include(
              'aiGatewayUrl' => 'http://new-ai-gateway-url',
              'duoCoreFeaturesEnabled' => nil
            )
            expect(result['errors']).to eq([])

            expect { duo_settings.reload }.to change { duo_settings.ai_gateway_url }.to('http://new-ai-gateway-url')
              .and not_change { duo_settings.duo_core_features_enabled }
          end
        end
      end
    end
  end
end
