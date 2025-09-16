# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Queues::Code, feature_category: :code_suggestions do
  describe '.number_of_shards' do
    it 'returns 1' do
      expect(described_class.number_of_shards).to eq(1)
    end
  end

  describe '.queues' do
    it 'includes the code queue' do
      expect(ActiveContext::Queues.queues).to include('ai_activecontext_queues:{code}')
    end
  end

  describe '.raw_queues' do
    it 'includes the code queue' do
      raw_queues = ActiveContext::Queues.raw_queues

      expect(raw_queues.any?(described_class)).to be true
    end
  end
end
