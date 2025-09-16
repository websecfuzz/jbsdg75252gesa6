# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::AiGateway::SelfHostedModels::TestedModelDetails, feature_category: :"self-hosted_models" do
  let(:user) { create(:user) }
  let_it_be(:self_hosted_model) { build(:ai_self_hosted_model) }

  subject(:tested_model_details) do
    described_class.new(current_user: user, self_hosted_model: self_hosted_model)
  end

  describe '#feature_disabled?' do
    it 'returns false' do
      expect(tested_model_details.feature_disabled?).to be(false)
    end
  end

  describe '#self_hosted?' do
    it 'returns false' do
      expect(tested_model_details.self_hosted?).to be(true)
    end
  end

  describe '#base_url' do
    let(:url) { 'http://0.0.0.0:5052' }

    it 'returns the AI Gateway URL' do
      expect(::Gitlab::AiGateway).to receive(:url).and_return(url)
      expect(tested_model_details.base_url).to eql(url)
    end
  end

  describe '#feature_setting' do
    let(:feature_setting) { tested_model_details.feature_setting }

    it 'returns the right attribute values' do
      expect(feature_setting.feature).to eql('code_completions')
      expect(feature_setting.provider).to eql('self_hosted')
    end

    describe '#self_hosted_model' do
      it 'returns the given self-hosted model' do
        expect(feature_setting.self_hosted_model).to be(self_hosted_model)
      end
    end
  end
end
