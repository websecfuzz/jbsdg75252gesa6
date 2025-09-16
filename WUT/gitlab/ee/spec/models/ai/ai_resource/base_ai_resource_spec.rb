# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::AiResource::BaseAiResource, feature_category: :duo_chat do
  describe '#serialize_for_ai' do
    it 'raises NotImplementedError' do
      expect { described_class.new(nil, nil).serialize_for_ai(_content_limit: nil) }
        .to raise_error(NotImplementedError)
    end
  end

  describe '#current_page_params' do
    it 'returns params to construct prompt' do
      expect { described_class.new(nil, nil).current_page_params }
        .to raise_error(NotImplementedError)
    end
  end

  describe '#default_content_limit' do
    it 'returns params to construct prompt' do
      expect(described_class.new(nil, nil).default_content_limit).to eq(100_000)
    end
  end
end
