# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'List of configurable namespace Model Selection feature settings.', feature_category: :"self-hosted_models" do
  include GraphqlHelpers

  let_it_be(:group_owner) { create(:user) }
  let_it_be(:group) { create(:group) }

  let_it_be(:feature_settings) do
    [
      create(:ai_namespace_feature_setting, feature: :code_completions, namespace: group),
      create(:ai_namespace_feature_setting, feature: :code_generations, namespace: group)
    ]
  end

  let_it_be(:test_ai_feature_enum) do
    {
      code_generations: 0,
      code_completions: 1,
      duo_chat: 2
    }
  end

  let(:feature_flags_enabled) { true }
  let(:namespace_duo_enabled) { true }
  let(:user) { group_owner }
  let(:group_gid) { group.to_global_id.to_s }
  let(:request_params) { { groupId: group_gid } }

  let(:query) do
    %(
      query AiModelSelectionNamespaces($groupId: GroupID!) {
        aiModelSelectionNamespaceSettings(groupId: $groupId) {
          nodes {
            feature
            title
            mainFeature
            selectedModel {
              ref
              name
            }
            selectableModels {
              ref
              name
            }
            defaultModel {
              ref
              name
            }
          }
        }
      }
    )
  end

  let(:fetch_service_stubbed_params) do
    {
      status: 200,
      body: model_definitions_response,
      headers: { 'Content-Type' => 'application/json' }
    }
  end

  include_context 'with model selections fetch definition service side-effect context'

  before_all do
    group.add_owner(group_owner)
  end

  before do
    allow(::Ai::ModelSelection::NamespaceFeatureSetting).to(
      receive(:enabled_features_for)
        .with(group)
        .and_return(test_ai_feature_enum)
    )

    stub_feature_flags(ai_model_switching: feature_flags_enabled)

    group.namespace_settings.update!(duo_features_enabled: namespace_duo_enabled)

    stub_request(:get, fetch_service_endpoint_url)
      .to_return(fetch_service_stubbed_params)
  end

  subject(:request) { post_graphql(query, current_user: user, variables: request_params) }

  describe '#resolve' do
    before do
      request
    end

    context 'with access issues' do
      context 'when the ai_model_switching feature flag is disabled' do
        let(:feature_flags_enabled) { false }

        it_behaves_like 'a query that returns a top-level access error'
      end

      context 'when duo is disabled for the namespace' do
        let(:namespace_duo_enabled) { false }

        it_behaves_like 'a query that returns a top-level access error'
      end

      context 'when the user does not have write access to the group' do
        let(:user) { create(:user) }

        it_behaves_like 'a query that returns a top-level access error'
      end

      context 'when the group is not found' do
        let(:group_gid) { "gid://gitlab/Group/0" }

        it_behaves_like 'a query that returns a top-level access error'
      end
    end

    context 'when the model definition fetch service fails' do
      let(:fetch_service_stubbed_params) do
        {
          status: 401,
          body: "{\"error\":\"No authorization header presented\"}",
          headers: { 'Content-Type' => 'application/json' }
        }
      end

      let(:expected_error_message) { 'Received error 401 from AI gateway when fetching model definitions' }

      it 'returns an error message' do
        result_data = json_response['data']['aiModelSelectionNamespaceSettings']
        result_errors = json_response['errors']

        expect(result_data).to be_nil

        expect(result_errors.first['message']).to eq(expected_error_message)
      end
    end

    context 'when there are no errors' do
      let(:request_data) { graphql_data_at(:aiModelSelectionNamespaceSettings, :nodes) }
      let(:expected_features) { %w[duo_chat code_generations code_completions] }

      let(:expected_selectable_models) do
        [
          { 'name' => 'Claude Sonnet 3.5', 'ref' => 'claude_sonnet_3_5' },
          { 'name' => 'Claude Sonnet 3.7', 'ref' => 'claude_sonnet_3_7' },
          { 'name' => 'OpenAI Chat GPT 4o', 'ref' => 'openai_chatgpt_4o' }
        ]
      end

      let(:expected_selected_models) do
        [
          { 'name' => 'Claude Sonnet 3.7', 'ref' => 'claude_sonnet_3_7' },
          { 'name' => 'Claude Sonnet 3.7', 'ref' => 'claude_sonnet_3_7' },
          nil
        ]
      end

      it 'returns the expected response' do
        result = json_response['data']['aiModelSelectionNamespaceSettings']

        expect(result['errors']).to be_nil
        expect(request_data.length).to eq(3)
        expect(request_data.pluck('feature')).to match_array(expected_features)
        expect(request_data.first['selectableModels']).to match_array(expected_selectable_models)
        expect(request_data.pluck('selectedModel')).to match_array(expected_selected_models)
      end
    end
  end
end
