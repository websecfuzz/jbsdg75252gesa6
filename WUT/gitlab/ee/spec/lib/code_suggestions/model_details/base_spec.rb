# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::ModelDetails::Base, feature_category: :code_suggestions do
  let_it_be(:feature_setting_name) { 'code_generations' }
  let(:user) { create(:user) }
  let(:root_namespace) { nil }
  let(:model_details) do
    described_class.new(current_user: user, feature_setting_name: feature_setting_name, root_namespace: root_namespace)
  end

  describe '#feature_setting' do
    it 'returns nil' do
      expect(model_details.feature_setting).to be_nil
    end

    context 'when the feature is governed via self-hosted models' do
      let_it_be(:feature_setting) { create(:ai_feature_setting, feature: feature_setting_name) }

      it 'returns the feature setting' do
        expect(model_details.feature_setting).to eq(feature_setting)
      end
    end

    context 'when the feature is governed via namespace feature setting' do
      let(:root_namespace) { create(:group) }
      let!(:namespace_feature_setting) do
        create(:ai_namespace_feature_setting,
          namespace: root_namespace,
          feature: feature_setting_name
        )
      end

      it 'returns the feature setting' do
        expect(model_details.feature_setting).to eq(namespace_feature_setting)
      end
    end
  end

  describe '#self_hosted?' do
    it 'returns false' do
      expect(model_details.self_hosted?).to be(false)
    end

    context 'when the feature is governed via self-hosted models' do
      let_it_be(:feature_setting) { create(:ai_feature_setting, feature: feature_setting_name) }

      it 'returns true' do
        expect(model_details.self_hosted?).to be(true)
      end
    end

    context 'when the feature is governed via namespace feature setting' do
      let(:root_namespace) { create(:group) }

      before do
        create(:ai_namespace_feature_setting,
          namespace: root_namespace,
          feature: feature_setting_name
        )
      end

      it 'returns false' do
        expect(model_details.self_hosted?).to be(false)
      end
    end
  end

  describe '#namespace_feature_setting?' do
    subject(:namespace_feature_setting?) { model_details.namespace_feature_setting? }

    it 'returns false' do
      expect(namespace_feature_setting?).to be(false)
    end

    context 'when the feature is governed via self-hosted models' do
      it 'returns false' do
        create(:ai_feature_setting, feature: feature_setting_name)

        expect(namespace_feature_setting?).to be(false)
      end
    end

    context 'when the feature is governed via namespace feature setting' do
      let!(:root_namespace) { create(:group) }
      let!(:namespace_feature_setting) do
        create(:ai_namespace_feature_setting,
          namespace: root_namespace,
          feature: feature_setting_name
        )
      end

      it 'returns true' do
        expect(namespace_feature_setting?).to be(true)
      end
    end
  end

  describe '#feature_disabled?' do
    subject(:feature_disabled?) { model_details.feature_disabled? }

    it 'returns false' do
      expect(feature_disabled?).to be(false)
    end

    context 'when the feature is self-hosted, but set to disabled' do
      let_it_be(:feature_setting) do
        create(:ai_feature_setting, provider: :disabled, feature: feature_setting_name)
      end

      it 'returns true' do
        expect(feature_disabled?).to be(true)
      end
    end

    context 'for namespace feature setting' do
      let(:root_namespace) { create(:group) }

      before do
        create(:ai_namespace_feature_setting,
          namespace: root_namespace,
          feature: feature_setting_name
        )
      end

      it 'returns false' do
        expect(feature_disabled?).to be(false)
      end
    end
  end

  describe '#base_url' do
    it 'returns correct URL' do
      expect(model_details.base_url).to eql('https://cloud.gitlab.com/ai')
    end

    context 'when the feature is governed via self-hosted models' do
      let_it_be(:feature_setting) { create(:ai_feature_setting, provider: :vendored) }

      it 'takes the base url from feature settings' do
        url = "http://localhost:5000"
        expect(::Gitlab::AiGateway).to receive(:cloud_connector_url).and_return(url)

        expect(model_details.base_url).to eq(url)
      end
    end

    context 'when the feature is governed via namespace feature setting' do
      let(:root_namespace) { create(:group) }

      before do
        create(:ai_namespace_feature_setting,
          namespace: root_namespace,
          feature: feature_setting_name
        )
      end

      it 'returns correct URL' do
        expect(model_details.base_url).to eql('https://cloud.gitlab.com/ai')
      end
    end
  end

  context 'when Amazon Q is connected' do
    let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_amazon_q) }

    it 'returns correct feature name and licensed feature' do
      stub_licensed_features(amazon_q: true)
      Ai::Setting.instance.update!(amazon_q_ready: true)

      expect(model_details.feature_name).to eq(:amazon_q_integration)
      expect(model_details.licensed_feature).to eq(:amazon_q)
    end
  end
end
