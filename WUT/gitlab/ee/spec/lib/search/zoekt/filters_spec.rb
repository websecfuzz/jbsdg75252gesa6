# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::Filters, feature_category: :global_search do
  describe '.by_substring' do
    it 'returns a substring filter with required pattern' do
      expect(described_class.by_substring(pattern: 'foo')).to eq({ substring: { pattern: 'foo' } })
    end

    it 'includes optional parameters if provided' do
      result = described_class.by_substring(pattern: 'foo', case_sensitive: true, file_name: 'bar', content: 'baz')
      expect(result).to eq({ substring: { pattern: 'foo', case_sensitive: true, file_name: 'bar', content: 'baz' } })
    end
  end

  describe '.by_repo_ids' do
    it 'raises error if ids is not an array' do
      expect { described_class.by_repo_ids('foo') }.to raise_error(ArgumentError)
    end

    it 'returns repo_ids as integers' do
      expect(described_class.by_repo_ids(['1', 2])).to eq({ repo_ids: [1, 2] })
    end
  end

  describe '.by_regexp' do
    it 'returns a regexp filter with required regexp' do
      expect(described_class.by_regexp(regexp: 'foo')).to eq({ regexp: { regexp: 'foo' } })
    end

    it 'includes optional parameters if provided' do
      result = described_class.by_regexp(regexp: 'foo', case_sensitive: false, file_name: 'bar', content: 'baz')
      expect(result).to eq({ regexp: { regexp: 'foo', case_sensitive: false, file_name: 'bar', content: 'baz' } })
    end
  end

  describe '.and_filters' do
    it 'returns an and filter with children' do
      expect(described_class.and_filters({ a: 1 }, { b: 2 })).to eq({ and: { children: [{ a: 1 }, { b: 2 }] } })
    end
  end

  describe '.or_filters' do
    it 'returns an or filter with children' do
      expect(described_class.or_filters({ a: 1 }, { b: 2 })).to eq({ or: { children: [{ a: 1 }, { b: 2 }] } })
    end
  end

  describe '.not_filter' do
    it 'returns a not filter with child' do
      expect(described_class.not_filter({ a: 1 })).to eq({ not: { child: { a: 1 } } })
    end
  end

  describe '.by_symbol' do
    it 'returns a symbol filter' do
      expect(described_class.by_symbol('foo')).to eq({ symbol: { expr: 'foo' } })
    end
  end

  describe '.by_meta' do
    it 'returns a meta filter' do
      expect(described_class.by_meta(key: 'foo', value: 'bar')).to eq({ meta: { key: 'foo', value: 'bar' } })
    end
  end

  describe '.by_query_string' do
    it 'returns a query_string filter' do
      expect(described_class.by_query_string('foo')).to eq({ query_string: { query: 'foo' } })
    end
  end
end
