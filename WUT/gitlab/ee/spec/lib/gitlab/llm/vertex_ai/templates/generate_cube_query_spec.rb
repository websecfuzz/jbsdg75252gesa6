# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::VertexAi::Templates::GenerateCubeQuery, feature_category: :product_analytics do
  let(:question) { "How many people used the application in the previous 7 days?" }
  let(:expected) do
    "The question you need to answer is \"How many people used the application in the previous 7 days?\""
  end

  subject(:template) { described_class.new(question) }

  describe '#to_prompt' do
    it 'includes inputted question' do
      expect(template.to_prompt).to include(expected)
    end
  end
end
