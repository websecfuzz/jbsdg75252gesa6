# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::AiGateway::SelfHostedModels::Tasks::ModelConfigCheck, feature_category: :"self-hosted_models" do
  let_it_be(:user) { create(:user) }
  let_it_be(:params) do
    {
      current_file: {
        file_name: 'test.rb',
        content_above_cursor: 'def hello_world'
      }
    }
  end

  let_it_be(:self_hosted_model) { build(:ai_self_hosted_model) }

  subject(:instance) do
    described_class.new(
      unsafe_passthrough_params: params,
      self_hosted_model: self_hosted_model,
      current_user: user
    )
  end

  describe "#new" do
    specify do
      expect(instance.send(:model_details)).to be_a(::Gitlab::Llm::AiGateway::SelfHostedModels::TestedModelDetails)
    end
  end

  describe "#endpoint" do
    let(:base_url) { Gitlab::AiGateway.url }

    specify do
      expect(instance.endpoint).to eq("#{base_url}/v1/prompts/model_configuration%2Fcheck")
    end
  end
end
