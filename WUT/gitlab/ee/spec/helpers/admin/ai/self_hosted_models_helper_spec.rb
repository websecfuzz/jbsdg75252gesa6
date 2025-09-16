# frozen_string_literal: true

require "spec_helper"

RSpec.describe Admin::Ai::SelfHostedModelsHelper, feature_category: :"self-hosted_models" do
  before do
    allow(::Ai::TestingTermsAcceptance).to receive(:has_accepted?).and_return(true)
  end

  describe '#model_choices_as_options' do
    it 'returns an array of hashes with model options sorted alphabetically' do
      expected_result = [
        { modelValue: "CLAUDE_3", modelName: "Claude 3", releaseState: "GA" },
        { modelValue: "CODELLAMA", modelName: "Code Llama", releaseState: "BETA" },
        { modelValue: "CODEGEMMA", modelName: "CodeGemma", releaseState: "BETA" },
        { modelValue: "DEEPSEEKCODER", modelName: "DeepSeek Coder", releaseState: "BETA" },
        { modelValue: "GPT", modelName: "GPT", releaseState: "GA" },
        { modelValue: "LLAMA3", modelName: "Llama 3", releaseState: "BETA" },
        { modelValue: "MISTRAL", modelName: "Mistral", releaseState: "GA" },
        { modelValue: "CODESTRAL", modelName: "Mistral Codestral", releaseState: "GA" },
        { modelValue: "MIXTRAL", modelName: "Mixtral", releaseState: "GA" }
      ]

      expect(helper.model_choices_as_options).to eq(expected_result)
    end

    it 'humanizes the model name when there is no mapped name available' do
      allow(::Ai::SelfHostedModel).to receive(:models).and_return(["unmapped_model"])

      expect(helper.model_choices_as_options).to eq([
        {
          modelValue: "UNMAPPED_MODEL",
          modelName: "Unmapped model",
          releaseState: nil
        }
      ])
    end

    it 'filters out beta models if they are not enabled' do
      allow(::Ai::TestingTermsAcceptance).to receive(:has_accepted?).and_return(false)

      expect(helper.model_choices_as_options).to eq([
        { modelValue: "CLAUDE_3", modelName: "Claude 3", releaseState: "GA" },
        { modelValue: "GPT", modelName: "GPT", releaseState: "GA" },
        { modelValue: "MISTRAL", modelName: "Mistral", releaseState: "GA" },
        { modelValue: "CODESTRAL", modelName: "Mistral Codestral", releaseState: "GA" },
        { modelValue: "MIXTRAL", modelName: "Mixtral", releaseState: "GA" }
      ])
    end
  end

  describe '#beta_models_enabled?' do
    it 'returns true if testing terms have been accepted' do
      expect(helper.beta_models_enabled?).to be(true)
    end

    it 'returns false if testing terms have not been accepted' do
      allow(::Ai::TestingTermsAcceptance).to receive(:has_accepted?).and_return(false)

      expect(helper.beta_models_enabled?).to be(false)
    end
  end
end
