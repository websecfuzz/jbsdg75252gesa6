# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::Concerns::SourceType, feature_category: :global_search do
  subject(:instance) { Class.new.include(described_class).new }

  describe 'TYPES constant' do
    it 'defines the correct ES query source types' do
      expect(described_class::TYPES).to eq({
        glql: 'glql',
        search: 'search',
        api: 'api'
      })
    end
  end

  describe '#glql_query?' do
    it 'returns true for glql source' do
      expect(instance.send(:glql_query?, 'glql')).to be_truthy
    end

    it 'returns false for nil' do
      expect(instance.send(:glql_query?, nil)).to be_falsey
    end
  end
end
