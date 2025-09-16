# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'GitLab Duo settings.', feature_category: :'self-hosted_models' do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:admin) }
  let_it_be(:duo_settings) { create(:ai_settings) }

  let(:query) do
    %(
      query getDuoSettings {
        duoSettings {
          aiGatewayUrl
          duoCoreFeaturesEnabled
        }
      }
    )
  end

  let(:duo_settings_data) { graphql_data_at(:duoSettings) }

  context 'when the user is authorized' do
    let_it_be(:license) { create(:license, plan: License::ULTIMATE_PLAN) }

    context 'when user is not authorized to manage Duo self-hosted settings' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :expired, :self_managed)
      end

      it 'returns nil for the Duo self-hosted setting' do
        post_graphql(query, current_user: current_user)

        expect(duo_settings_data).to eq(
          {
            'aiGatewayUrl' => nil,
            'duoCoreFeaturesEnabled' => false
          }
        )
      end
    end

    context 'when user is not authorized for Duo Core features' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :active, :self_managed)
      end

      before do
        stub_licensed_features(code_suggestions: false, ai_chat: false)
      end

      it 'returns nil for the Duo Core features setting' do
        post_graphql(query, current_user: current_user)

        expect(duo_settings_data).to eq(
          {
            'aiGatewayUrl' => 'http://0.0.0.0:5052',
            'duoCoreFeaturesEnabled' => nil
          }
        )
      end
    end

    context 'when user is authorized for everything' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :active, :self_managed)
      end

      it 'returns the expected response' do
        post_graphql(query, current_user: current_user)

        expect(duo_settings_data).to eq(
          {
            'aiGatewayUrl' => 'http://0.0.0.0:5052',
            'duoCoreFeaturesEnabled' => false
          }
        )
      end
    end
  end

  context 'when the user is not authorized for anything' do
    it 'returns nil for the unauthorized settings' do
      post_graphql(query, current_user: current_user)

      expect(duo_settings_data).to eq(
        {
          'aiGatewayUrl' => nil,
          'duoCoreFeaturesEnabled' => nil
        }
      )
    end
  end
end
