# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::Query, feature_category: :global_search do
  describe 'initialize' do
    it 'instantiates and can read the attributes' do
      instance = described_class.new('test', source: :api)
      expect(instance.query).to eq 'test'
      expect(instance.source).to eq :api
    end

    context 'when source is not passed' do
      it 'instantiates with nil source and can read the attributes' do
        instance = described_class.new('test')
        expect(instance.query).to eq 'test'
        expect(instance.source).to be_nil
      end
    end

    context 'when query is nil' do
      it 'raises an exception on instance initialization' do
        expect { described_class.new(nil) }.to raise_error(ArgumentError, 'query argument can not be nil')
      end
    end

    context 'when query is not passed' do
      it 'raises an exception on instance initialization' do
        expect { described_class.new }.to raise_error(ArgumentError, 'wrong number of arguments (given 0, expected 1)')
      end
    end
  end

  describe '#formatted_query' do
    using RSpec::Parameterized::TableSyntax

    context 'for exact mode and source is not api' do
      where(:query, :result) do
        ''                              | ''
        'test'                          | 'test'
        '^test.*\b\d+(a|b)[0-9]\sa{3}$' | %q(\^test\.\*\\\b\\\d\+\\(a\|b\\)\[0\-9\]\\\sa\{3\}\$)
        '"foo"'                         | %q(\"foo\")
        'lang:ruby    test'             | 'test lang:ruby'
        'case:no test'                  | 'test case:no'
        'foo:bar test'                  | 'foo\:bar\ test'
        'test    case:auto'             | 'test case:auto'
        'case:no test f:dummy.rb'       | 'test case:no f:dummy.rb'
        'case:no test -f:dummy.rb'      | 'test case:no -f:dummy.rb'
        'case:no file:dummy test'       | 'test case:no file:dummy'
        'case:no -file:dummy test'      | 'test case:no -file:dummy'
        'test case:no file:dummy'       | 'test case:no file:dummy'
        'test sym:foo'                  | 'test sym:foo'
        'sym:foo'                       | 'sym:foo'
        'test extension:rb'             | 'test extension:rb' # No transpilation required when source is not api
      end

      with_them do
        it 'returns correct exact search query' do
          expect(described_class.new(query).formatted_query(:exact)).to eq result
        end
      end
    end

    context 'for regex mode and source is api' do
      where(:query, :result) do
        'test extension:rb'       | 'test file:\.rb$'
        'test -extension:go'      | 'test -file:\.go$'
        'hello filename:foobar'   | 'hello file:/([^/]*foobar[^/]*)$'
        'te.* -path:hello/world'  | 'te.* -file:(?:^|/)hello/world'
        'test lang:rb'            | 'test lang:rb' # No transpilation required because syntax is exact code search
      end

      with_them do
        it 'returns correct zoekt search query syntax' do
          expect(described_class.new(query, source: :api).formatted_query(:regex)).to eq result
        end
      end

      context 'when FF zoekt_syntax_transpile is disabled' do
        let(:query) { 'extension:rb' }

        before do
          stub_feature_flags(zoekt_syntax_transpile: false)
        end

        it 'does not converts the syntax' do
          expect(described_class.new(query, source: :api).formatted_query(:regex)).to eq query
        end
      end
    end
  end
end
