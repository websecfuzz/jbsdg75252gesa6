# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::ModelDetails::CodeCompletion, feature_category: :code_suggestions do
  include GitlabSubscriptions::SaasSetAssignmentHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group1) { create(:group) }
  let_it_be(:group2) { create(:group) }

  let_it_be(:group1_addon) do
    create(
      :gitlab_subscription_add_on_purchase,
      add_on: create(:gitlab_subscription_add_on, :duo_pro),
      namespace: group1
    ).tap do |addon|
      add_user_to_group(user, addon)
    end
  end

  let_it_be(:group2_addon) do
    create(
      :gitlab_subscription_add_on_purchase,
      add_on: create(:gitlab_subscription_add_on, :duo_enterprise),
      namespace: group2
    ).tap do |addon|
      add_user_to_group(user, addon)
    end
  end

  let(:completions_model_details) { described_class.new(current_user: user) }

  shared_examples 'selects the correct model' do
    before do
      stub_feature_flags(use_claude_code_completion: false)
    end

    context 'when using Fireworks/Codestral' do
      before do
        stub_feature_flags(code_completion_opt_out_fireworks: false)
      end

      context 'on GitLab self-managed' do
        before do
          allow(Gitlab).to receive(:org_or_com?).and_return(false)
        end

        it 'returns the fireworks/codestral model' do
          expect(actual_result).to eq(expected_fireworks_codestral_result)
        end

        context 'when opted out of Fireworks through the ops FF' do
          before do
            stub_feature_flags(code_completion_opt_out_fireworks: true)
          end

          it 'returns the codestral on vertex' do
            expect(actual_result).to eq(expected_codestral_result)
          end
        end
      end

      context 'on GitLab saas' do
        before do
          allow(Gitlab).to receive(:org_or_com?).and_return(true)
        end

        it 'returns the fireworks/codestral model' do
          expect(actual_result).to eq(expected_fireworks_codestral_result)
        end

        context "when one of user's root groups has opted out of Fireworks" do
          before do
            # opt out for group2
            stub_feature_flags(code_completion_opt_out_fireworks: group2)
          end

          it 'returns the codestral on vertex' do
            expect(actual_result).to eq(expected_codestral_result)
          end

          describe 'executed queries for user_duo_groups' do
            it 'executes the expected number of queries' do
              # We are only expecting 3 queries:
              # 1 - for ModelDetails::Completions#feature_setting
              # 2 - for current_user#duo_available_namespace_ids in ModelDetails::Completions#user_duo_groups
              # 3 - for Group.by_id(<group ids>) in ModelDetails::Completions#user_duo_groups
              expect { actual_result }.not_to exceed_query_limit(3)
            end
          end
        end
      end
    end

    context 'when code_completions is self-hosted' do
      before do
        feature_setting_double = instance_double(::Ai::FeatureSetting, self_hosted?: true)
        allow(::Ai::FeatureSetting).to receive(:find_by_feature).with('code_completions')
          .and_return(feature_setting_double)
      end

      it 'returns the self-hosted model' do
        expect(actual_result).to eq(expected_self_hosted_model_result)
      end
    end
  end

  describe '#current_model' do
    it_behaves_like 'selects the correct model' do
      subject(:actual_result) { completions_model_details.current_model }

      let(:expected_codestral_result) do
        {
          model_provider: 'vertex-ai',
          model_name: 'codestral-2501'
        }
      end

      let(:expected_fireworks_codestral_result) do
        {
          model_provider: 'fireworks_ai',
          model_name: 'codestral-2501'
        }
      end

      let(:expected_claude_result) { {} }

      let(:expected_self_hosted_model_result) { {} }
    end
  end

  describe '#saas_primary_model_class' do
    it_behaves_like 'selects the correct model' do
      subject(:actual_result) { completions_model_details.saas_primary_model_class }

      let(:expected_codestral_result) do
        CodeSuggestions::Prompts::CodeCompletion::VertexCodestral
      end

      let(:expected_fireworks_codestral_result) do
        CodeSuggestions::Prompts::CodeCompletion::FireworksCodestral
      end

      let(:expected_default_result) do
        CodeSuggestions::Prompts::CodeCompletion::Default
      end

      let(:expected_claude_result) do
        CodeSuggestions::Prompts::CodeCompletion::Anthropic::ClaudeHaiku
      end

      let(:expected_self_hosted_model_result) { nil }
    end
  end

  describe '#user_group_with_claude_code_completion' do
    before do
      stub_feature_flags(use_claude_code_completion: false)
    end

    context "when none of the user's root groups is using claude code completion model" do
      it 'returns false' do
        expect(completions_model_details.user_group_with_claude_code_completion).to be_nil
      end
    end

    context "when one of user's root groups is using claude code completion model" do
      before do
        stub_feature_flags(use_claude_code_completion: group2)
      end

      it 'returns the specific group' do
        expect(completions_model_details.user_group_with_claude_code_completion).to eq(group2)
      end
    end
  end

  describe '#any_user_groups_with_model_selected_for_completion?' do
    let!(:user1) { create(:user) }
    let!(:user2) { create(:user) }

    subject { model_details.any_user_groups_with_model_selected_for_completion? }

    before do
      add_user_to_group(user1, group1_addon)
      add_user_to_group(user2, group1_addon)
      add_user_to_group(user2, group2_addon)

      create(:ai_namespace_feature_setting, feature: :code_completions, namespace: group2)

      stub_feature_flags(ai_model_switching: false)
    end

    context 'when user has no Duo access' do
      let(:model_details) { described_class.new(current_user: create(:user)) }

      it { is_expected.to be(false) }
    end

    context 'when user has Duo access' do
      let(:model_details) { described_class.new(current_user: user1) }

      context 'when no groups have model selection' do
        it { is_expected.to be(false) }
      end

      context 'when user is part of a group that has set up a model selection record' do
        let(:model_details) { described_class.new(current_user: user2) }

        context 'when no groups have model selection feature flag enabled' do
          it { is_expected.to be(false) }
        end

        context 'when one group has model selection feature flag enabled' do
          before do
            stub_feature_flags(ai_model_switching: group2)
          end

          it { is_expected.to be(true) }
        end
      end
    end
  end
end
