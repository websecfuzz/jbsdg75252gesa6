# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::Types::WorkItem, feature_category: :global_search do
  let(:helper) { Gitlab::Elastic::Helper.default }

  before do
    allow(Gitlab::Elastic::Helper).to receive(:default).and_return(helper)
  end

  describe '#target' do
    it 'returns work_item class' do
      expect(described_class.target.class.name).to eq(WorkItem.class.name)
    end
  end

  describe '#index_name' do
    it 'returns correct environment based index name' do
      expect(described_class.index_name).to eq('gitlab-test-work_items')
    end
  end

  describe '#mappings' do
    let(:mappings) { described_class.mappings.to_hash[:properties] }
    let(:expected_dimensions) { described_class::VERTEX_TEXT_EMBEDDING_DIMENSION }

    it 'always contains base mappings' do
      expect(mappings.keys).to include(:id)
    end

    it 'contains platform and version specific mappings' do
      if helper.vectors_supported?(:elasticsearch)
        expect(mappings.keys).to include(:embedding_0, :embedding_1)

        expect(mappings[:embedding_0][:dims]).to eq(expected_dimensions)
        expect(mappings[:embedding_1][:dims]).to eq(expected_dimensions)
      end

      if helper.vectors_supported?(:opensearch)
        expect(mappings.keys).to include(:embedding_0, :embedding_1)

        expect(mappings[:embedding_0][:dimension]).to eq(expected_dimensions)
        expect(mappings[:embedding_1][:dimension]).to eq(expected_dimensions)
      end
    end
  end

  describe '#elastic_knn_field' do
    it 'returns a properly configured dense_vector field' do
      expected_field = {
        type: 'dense_vector',
        dims: described_class::VERTEX_TEXT_EMBEDDING_DIMENSION,
        similarity: 'cosine',
        index: true
      }

      expect(described_class.elastic_knn_field).to eq(expected_field)
    end
  end

  describe '#opensearch_knn_field' do
    let(:helper) { Gitlab::Elastic::Helper.default }
    let(:version) { '1.0.0' }
    let(:distribution) { 'opensearch' }
    let(:info) { { version: version, distribution: distribution } }

    before do
      allow(Gitlab::Elastic::Helper).to receive(:default).and_return(helper)
      allow(helper).to receive(:server_info).and_return(info)
    end

    it 'returns a properly configured knn_vector field' do
      expected_field = {
        type: 'knn_vector',
        dimension: described_class::VERTEX_TEXT_EMBEDDING_DIMENSION,
        method: {
          name: 'hnsw',
          engine: 'nmslib',
          space_type: 'cosinesimil',
          parameters: {
            ef_construction: described_class::OPENSEARCH_EF_CONSTRUCTION,
            m: described_class::OPENSEARCH_M
          }
        }
      }

      expect(described_class.opensearch_knn_field).to eq(expected_field)
    end

    describe 'engine' do
      using RSpec::Parameterized::TableSyntax

      where(:distribution, :version, :engine) do
        'opensearch'    | '1.0.0'   | 'nmslib'
        'opensearch'    | '2.1.0'   | 'nmslib'
        'opensearch'    | '2.2.1'   | 'lucene'
        'opensearch'    | '3.0.0'   | 'lucene'
        'elasticsearch' | '7.17.28⁠' | 'nmslib'
        'elasticsearch' | '8.18.1⁠2⁠' | 'nmslib'
      end

      with_them do
        it 'sets the right engine' do
          expect(described_class.opensearch_knn_field[:method][:engine]).to eq(engine)
        end
      end
    end
  end

  describe '#settings' do
    let(:settings) { described_class.settings.to_hash[:index].keys }

    it 'always contains base settings' do
      expect(settings).to include(:number_of_shards)
    end

    it 'contains platform and version specific mappings' do
      expect(settings).to include(:knn) if helper.vectors_supported?(:opensearch)
    end
  end
end
