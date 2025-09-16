# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::Prompts::CodeCompletion::ModelSwitching::AiGateway, feature_category: :"self-hosted_models" do
  let(:params) { { project: create(:project) } }
  let_it_be(:user_group_with_claude_code_completion) { nil }
  let_it_be(:namespace_feature_setting) do
    create(:ai_namespace_feature_setting,
      feature: :code_completions,
      offered_model_ref: 'claude_sonnet_3_7_20250219',
      namespace: create(:group)
    )
  end

  let_it_be(:current_user) { create(:user) }

  let(:prompt) do
    described_class.new(
      params,
      current_user,
      namespace_feature_setting,
      user_group_with_claude_code_completion
    )
  end

  describe '#request_params' do
    subject(:request_params) { prompt.request_params }

    let(:expected_params) do
      {
        model_provider: 'gitlab',
        model_name: namespace_feature_setting&.offered_model_ref,
        prompt_version: 3,
        prompt: expected_prompt
      }
    end

    context 'when the model pinned is an Anthropic model' do
      let(:expected_prompt) do
        [
          { content: be_a(String), role: :system },
          { content: nil, role: :user }
        ]
      end

      it 'returns the correct request params, with prompt included' do
        expect(request_params).to include(expected_params)
      end
    end

    context 'when the model pinned is not an Anthropic model' do
      let_it_be(:namespace_feature_setting) do
        create(:ai_namespace_feature_setting,
          feature: :code_completions,
          offered_model_ref: 'codestral_2501_fireworks',
          namespace: create(:group)
        )
      end

      let(:expected_prompt) { nil }

      it 'returns the correct request params, with no prompt included' do
        expect(request_params).to include(expected_params)
      end
    end

    context 'when user_group_with_claude_code_completion is present' do
      let(:expected_prompt) do
        [
          { content: be_a(String), role: :system },
          { content: nil, role: :user }
        ]
      end

      let_it_be(:user_group_with_claude_code_completion) { create(:group) }

      shared_examples "claude group's behavior" do
        context "when the claude group's feature setting is set to gitlab default" do
          before do
            create(:ai_namespace_feature_setting,
              feature: :code_completions,
              offered_model_ref: '',
              namespace: user_group_with_claude_code_completion
            )
          end

          it 'returns params with the gitlab provided haiku model' do
            haiku_model_name = described_class::GITLAB_PROVIDED_CLAUDE_HAIKU_MODEL_NAME
            expect(request_params).to include(expected_params.merge(model_name: haiku_model_name))
          end
        end

        context 'when the claude group has set a different model for code completion' do
          before do
            create(:ai_namespace_feature_setting,
              feature: :code_completions,
              offered_model_ref: 'claude_sonnet_3_7_20250219',
              namespace: user_group_with_claude_code_completion
            )
          end

          it 'returns params with the model set by the claude group' do
            expect(request_params).to include(expected_params.merge(model_name: 'claude_sonnet_3_7_20250219'))
          end
        end

        context "when the claude group has no feature setting" do
          it 'returns params with the gitlab provided haiku model' do
            haiku_model_name = described_class::GITLAB_PROVIDED_CLAUDE_HAIKU_MODEL_NAME
            expect(request_params).to include(expected_params.merge(model_name: haiku_model_name))
          end
        end
      end

      include_examples "claude group's behavior"

      context 'when the namespace has no feature setting' do
        let(:namespace_feature_setting) { nil }

        it 'logs a debug message' do
          debug_params = {
            class: described_class.name,
            message: 'Model switching executed for code completion without a feature setting',
            root_namespace_id: params[:project]&.root_namespace&.id,
            user_group_with_claude_code_completion_id: user_group_with_claude_code_completion.id,
            model_to_be_used: described_class::GITLAB_PROVIDED_CLAUDE_HAIKU_MODEL_NAME
          }.stringify_keys

          expect(Gitlab::AppJsonLogger).to receive(:debug).with(debug_params)

          request_params
        end

        include_examples "claude group's behavior"
      end
    end
  end
end
