# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::SelfHostedModel, feature_category: :"self-hosted_models" do
  describe 'validation' do
    subject(:self_hosted_model) { build(:ai_self_hosted_model) }

    it { is_expected.to validate_presence_of(:endpoint) }
    it { is_expected.to validate_presence_of(:model) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name) }
    it { is_expected.to validate_length_of(:identifier).is_at_most(255) }
    it { is_expected.to allow_value('http://gitlab.com/s').for(:endpoint) }
    it { is_expected.not_to allow_value('javascript:alert(1)').for(:endpoint) }

    describe '#ga_models' do
      let_it_be(:beta_model) { create(:ai_self_hosted_model, name: 'Beta model', model: :codellama) }
      let_it_be(:ga_model) { create(:ai_self_hosted_model, name: 'GA model', model: :mistral) }

      it { expect(described_class.ga_models).not_to include(beta_model) }
      it { expect(described_class.ga_models).to match_array([ga_model]) }
    end

    describe '#api_token' do
      let(:token) { 'random_token' }

      it 'ensures that it encrypts api tokens' do
        self_hosted_model.api_token = token
        self_hosted_model.save!

        expect(self_hosted_model.persisted?).to be_truthy
        expect(self_hosted_model.reload.api_token).to eq(token)
        expect(self_hosted_model.reload.encrypted_api_token).not_to include(token)
      end
    end

    describe '#provider' do
      it 'returns openai symbol' do
        expect(self_hosted_model.provider).to eq(:openai)
      end
    end

    describe '#identifier' do
      subject(:self_hosted_model) { build(:ai_self_hosted_model, identifier: nil) }

      it 'coerces null values to empty string' do
        expect(self_hosted_model.identifier).to eq('')
      end
    end

    describe '#release_state' do
      Ai::SelfHostedModel::MODELS_RELEASE_STATE.each do |model, expected_state|
        context "when model is #{model}" do
          subject(:self_hosted_model) { build(:ai_self_hosted_model, model: model) }

          it "returns #{expected_state}" do
            expect(self_hosted_model.release_state).to eq(expected_state)
          end
        end
      end

      context 'when model is not listed in MODELS_RELEASE_STATE' do
        subject(:self_hosted_model) { build(:ai_self_hosted_model, model: nil) }

        it 'returns EXPERIMENTAL as default release state' do
          expect(self_hosted_model.release_state).to eq(Ai::SelfHostedModel::RELEASE_STATE_EXPERIMENTAL)
        end
      end
    end

    describe '#ga?' do
      it 'returns true if the model is in GA' do
        expect(self_hosted_model.ga?).to be(true)
      end
    end
  end
end
