# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'List of configurable AI feature with metadata.', feature_category: :"self-hosted_models" do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:admin) }
  let_it_be(:license) { create(:license, plan: License::ULTIMATE_PLAN) }
  let_it_be(:add_on_purchase) do
    create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :active, :self_managed)
  end

  let(:query) do
    %(
      query aiFeatureSettings {
        aiFeatureSettings {
          nodes {
            feature
            title
            mainFeature
            compatibleLlms
            provider
            releaseState
            selfHostedModel {
              id
              name
              model
              modelDisplayName
              releaseState
            }
            validModels {
              nodes {
                id
                name
                model
                modelDisplayName
                releaseState
              }
            }
          }
        }
      }
    )
  end

  let_it_be(:self_hosted_model) do
    create(:ai_self_hosted_model, name: 'model_name', model: :mistral)
  end

  let_it_be(:feature_setting) do
    create(:ai_feature_setting,
      self_hosted_model: self_hosted_model,
      feature: :code_completions,
      provider: :self_hosted
    )
  end

  let(:ai_feature_settings_data) { graphql_data_at(:aiFeatureSettings, :nodes) }

  let(:test_ai_feature_enum) do
    {
      code_generations: 0,
      code_completions: 1
    }
  end

  let(:model_name_mapper) { ::Admin::Ai::SelfHostedModelsHelper::MODEL_NAME_MAPPER }

  before do
    allow(::Ai::FeatureSetting).to receive(:allowed_features).and_return(test_ai_feature_enum)
  end

  context "when the user is authorized" do
    context 'when no query parameters are given' do
      let(:expected_response) do
        test_ai_feature_enum.keys.map do |feature|
          feature_setting = ::Ai::FeatureSetting.find_or_initialize_by_feature(feature)

          generate_feature_setting_data(feature_setting)
        end
      end

      it 'returns the expected response' do
        post_graphql(query, current_user: current_user)

        expect(ai_feature_settings_data).to match_array(expected_response)
      end
    end

    context 'when an Self-hosted model ID query parameters are given' do
      let(:query) do
        %(
          query aiFeatureSettings {
            aiFeatureSettings(selfHostedModelId: "#{model_gid}") {
              nodes {
                feature
                title
                mainFeature
                compatibleLlms
                provider
                releaseState
                selfHostedModel {
                  id
                  name
                  model
                  modelDisplayName
                  releaseState
                }
                validModels {
                  nodes {
                    id
                    name
                    model
                    modelDisplayName
                    releaseState
                  }
                }
              }
            }
          }
        )
      end

      context 'when the self-hosted model id exists' do
        let(:model_gid) { self_hosted_model.to_global_id }

        let(:expected_response) do
          feature_setting = ::Ai::FeatureSetting.find_or_initialize_by_feature(:code_completions)

          [generate_feature_setting_data(feature_setting)]
        end

        it 'returns the expected response' do
          post_graphql(query, current_user: current_user)

          expect(ai_feature_settings_data).to match_array(expected_response)
        end
      end

      context 'when the self-hosted model id does not exist' do
        let(:model_gid) { "gid://gitlab/Ai::SelfHostedModel/999999" }

        it 'returns the expected response' do
          post_graphql(query, current_user: current_user)

          expect(ai_feature_settings_data).to be_empty
        end
      end
    end
  end

  context 'when the user is not authorized' do
    let(:current_user) { create(:user) }

    it 'does not return feature settings' do
      post_graphql(query, current_user: current_user)
      expect(graphql_data['aiFeatureSettings']).to be_nil
    end
  end

  def generate_feature_setting_data(feature_setting)
    {
      'feature' => feature_setting.feature.to_s,
      'title' => feature_setting.title,
      'mainFeature' => feature_setting.main_feature,
      'compatibleLlms' => feature_setting.compatible_llms,
      'provider' => feature_setting.provider.to_s,
      'releaseState' => feature_setting.release_state,
      'selfHostedModel' => generate_self_hosted_data(feature_setting.self_hosted_model),
      'validModels' => {
        'nodes' => feature_setting.compatible_self_hosted_models.map { |s| generate_self_hosted_data(s) }
      }
    }
  end

  def generate_self_hosted_data(self_hosted_model)
    return unless self_hosted_model

    {
      'id' => self_hosted_model.to_global_id.to_s,
      'name' => self_hosted_model.name,
      'model' => self_hosted_model.model,
      'modelDisplayName' => model_name_mapper[self_hosted_model.model],
      'releaseState' => self_hosted_model.release_state
    }
  end
end
