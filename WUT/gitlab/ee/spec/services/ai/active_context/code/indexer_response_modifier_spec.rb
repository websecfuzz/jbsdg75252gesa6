# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Code::IndexerResponseModifier, feature_category: :global_search do
  describe '.extract_ids' do
    subject(:extract_ids) { described_class.extract_ids(result) }

    context 'with valid indexer output containing string IDs' do
      let(:result) do
        <<~OUTPUT
          --section-start--
          version,build_time
          v5.6.0-16-gb587744-dev,2025-06-24-0800 UTC
          --section-start--
          id
          hash123
          hash456
          {"time":"2025-06-24T10:02:09.778727+02:00","level":"ERROR","msg":"failed"}
        OUTPUT
      end

      it 'extracts only the IDs' do
        expect(extract_ids).to contain_exactly('hash123', 'hash456')
      end
    end

    context 'with multiple section markers' do
      let(:result) do
        <<~OUTPUT
          --section-start--
          version,build_time
          v5.6.0-16-gb587744-dev,2025-06-24-0800 UTC
          --section-start--
          id
          hash123
          hash456
          --section-start--
          another_section
          some_data
        OUTPUT
      end

      it 'extracts only the IDs from the correct section' do
        expect(extract_ids).to contain_exactly('hash123', 'hash456')
      end
    end

    context 'with IDs containing whitespace' do
      let(:result) do
        <<~OUTPUT
          --section-start--
          id
           hash123
          	hash456
        OUTPUT
      end

      it 'strips whitespace from IDs' do
        expect(extract_ids).to contain_exactly('hash123', 'hash456')
      end
    end

    context 'with empty lines in the ID section' do
      let(:result) do
        <<~OUTPUT
          --section-start--
          id
          hash123

          hash456

        OUTPUT
      end

      it 'filters out empty lines' do
        expect(extract_ids).to contain_exactly('hash123', 'hash456')
      end
    end

    context 'with no ID section' do
      let(:result) do
        <<~OUTPUT
          --section-start--
          version,build_time
          v5.6.0-16-gb587744-dev,2025-06-24-0800 UTC
          --section-start--
          not_id
          hash123
          hash456
        OUTPUT
      end

      it 'returns an empty array' do
        expect(extract_ids).to eq([])
      end
    end

    context 'with empty output' do
      let(:result) { '' }

      it 'returns an empty array' do
        expect(extract_ids).to eq([])
      end
    end

    context 'with nil output' do
      let(:result) { nil }

      it 'returns an empty array' do
        expect(extract_ids).to eq([])
      end
    end
  end
end
