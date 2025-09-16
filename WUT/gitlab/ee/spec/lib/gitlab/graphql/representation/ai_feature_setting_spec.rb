# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Graphql::Representation::AiFeatureSetting, feature_category: :"self-hosted_models" do
  let :feature_setting_params do
    [
      { feature: :duo_chat, provider: :vendored, self_hosted_model: nil },
      { feature: :code_completions, provider: :vendored, self_hosted_model: nil },
      { feature: :code_generations, provider: :vendored, self_hosted_model: nil }
    ]
  end

  let :feature_settings do
    feature_setting_params.map { |params| create(:ai_feature_setting, **params) }
  end

  let :model_params do
    [
      { name: 'vllm-codellama', model: :codellama },
      { name: 'vllm-codegemma', model: :codegemma },
      { name: 'vllm-mistral', model: :mistral }
    ]
  end

  let :self_hosted_models do
    model_params.map { |params| create(:ai_self_hosted_model, **params) }
  end

  before do
    allow(::Ai::TestingTermsAcceptance).to receive(:has_accepted?).and_return(true)
  end

  describe '.decorate' do
    context 'when feature_settings is nil' do
      it 'returns nil' do
        expect(described_class.decorate(nil)).to eq []
      end
    end

    context 'when feature_settings is present' do
      it 'returns an array of decorated objects' do
        result = described_class.decorate(feature_settings)
        expect(result).to all(be_a(described_class))
      end

      context 'when with_valid_models is true' do
        it 'calls decorate_with_valid_models' do
          expect(described_class).to receive(:decorate_with_valid_models).with(feature_settings)
          described_class.decorate(feature_settings, with_valid_models: true)
        end
      end

      context 'when with_valid_models is false' do
        it 'does not call decorate_with_valid_models' do
          expect(described_class).not_to receive(:decorate_with_valid_models)
          described_class.decorate(feature_settings, with_valid_models: false)
        end
      end
    end
  end

  describe '.decorate_with_valid_models' do
    let(:result) { described_class.decorate_with_valid_models(feature_settings) }

    let(:duo_chat_valid_models) { result.first.valid_models.map(&:name) }
    let(:code_generation_valid_models) { result.second.valid_models.map(&:name) }
    let(:code_completion_valid_models) { result.third.valid_models.map(&:name) }

    before do
      allow(::Ai::SelfHostedModel).to receive(:all).and_return(self_hosted_models)
    end

    it 'returns an array of decorated objects with valid models, sorted by name' do
      expect(duo_chat_valid_models).to eq(["vllm-mistral"])
      expect(code_generation_valid_models).to eq(%w[vllm-codegemma vllm-codellama vllm-mistral])
      expect(code_completion_valid_models).to eq(%w[vllm-codegemma vllm-codellama vllm-mistral])
    end

    context 'when the testing terms have not been accepted' do
      before do
        allow(::Ai::TestingTermsAcceptance).to receive(:has_accepted?).and_return(false)
      end

      it 'returns an array of decorated objects with valid models, excluding beta models' do
        expect(duo_chat_valid_models).to eq(["vllm-mistral"])
        expect(code_generation_valid_models).to eq(%w[vllm-mistral])
        expect(code_completion_valid_models).to eq(%w[vllm-mistral])
      end
    end
  end

  describe '#initialize' do
    it 'sets the feature_setting and valid_models', :aggregate_failures do
      decorated = described_class.new(feature_settings.first, valid_models: self_hosted_models)

      expect(decorated.valid_models).to eq(self_hosted_models)
      expect(decorated.__getobj__).to eq(feature_settings.first)
    end

    it 'defaults valid_models to an empty array' do
      decorated = described_class.new(feature_settings.first)
      expect(decorated.valid_models).to eq([])
    end
  end
end
