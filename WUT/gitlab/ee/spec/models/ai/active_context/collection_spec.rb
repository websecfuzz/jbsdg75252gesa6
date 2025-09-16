# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Collection, feature_category: :global_search do
  subject(:collection) { create(:ai_active_context_collection) }

  it { is_expected.to be_valid }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_length_of(:name).is_at_most(255) }
  it { is_expected.to validate_uniqueness_of(:name).scoped_to(:connection_id) }

  it { is_expected.to validate_presence_of(:number_of_partitions) }
  it { is_expected.to validate_numericality_of(:number_of_partitions).is_greater_than_or_equal_to(1).only_integer }

  it { is_expected.to validate_presence_of(:connection_id) }

  it { is_expected.to belong_to(:connection).class_name('Ai::ActiveContext::Connection') }

  describe 'metadata' do
    it 'is valid when empty' do
      collection.metadata = {}
      expect(collection).to be_valid
    end

    it 'is valid with search_embedding_version as a positive integer' do
      collection.metadata = { search_embedding_version: 1 }
      expect(collection).to be_valid
    end

    it 'is valid with search_embedding_version as zero' do
      collection.metadata = { search_embedding_version: 0 }
      expect(collection).to be_valid
    end

    it 'is valid with search_embedding_version as null' do
      collection.metadata = { search_embedding_version: nil }
      expect(collection).to be_valid
    end

    it 'is invalid with search_embedding_version as a negative number' do
      collection.metadata = { search_embedding_version: -1 }
      expect(collection).not_to be_valid
      expect(collection.errors[:metadata]).to include('must be a valid json schema')
    end

    it 'is valid with indexing_embedding_versions as an array of integers' do
      collection.metadata = { indexing_embedding_versions: [0, 1, 2] }
      expect(collection).to be_valid
    end

    it 'is valid with indexing_embedding_versions as an empty array' do
      collection.metadata = { indexing_embedding_versions: [] }
      expect(collection).to be_valid
    end

    it 'is invalid with indexing_embedding_versions containing negative numbers' do
      collection.metadata = { indexing_embedding_versions: [1, -1, 3] }
      expect(collection).not_to be_valid
      expect(collection.errors[:metadata]).to include('must be a valid json schema')
    end

    it 'is invalid when indexing_embedding_versions is not an array' do
      collection.metadata = { indexing_embedding_versions: 1 }
      expect(collection).not_to be_valid
      expect(collection.errors[:metadata]).to include('must be a valid json schema')
    end

    it 'is valid with both search_embedding_version and indexing_embedding_versions' do
      collection.metadata = {
        search_embedding_version: 1,
        indexing_embedding_versions: [2, 3, 4]
      }
      expect(collection).to be_valid
    end

    it 'is valid with include_ref_fields as true' do
      collection.metadata = { include_ref_fields: true }
      expect(collection).to be_valid
    end

    it 'is invalid when include_ref_fields is null' do
      collection.metadata = { include_ref_fields: nil }
      expect(collection).not_to be_valid
      expect(collection.errors[:metadata]).to include('must be a valid json schema')
    end

    it 'is valid with collection_class as a string' do
      collection.metadata = { collection_class: 'A string' }
      expect(collection).to be_valid
    end

    it 'is invalid with arbitrary properties' do
      collection.metadata = { key: 'value' }
      expect(collection).not_to be_valid
      expect(collection.errors[:metadata]).to include('must be a valid json schema')
    end
  end

  describe '.partition_for' do
    using RSpec::Parameterized::TableSyntax

    let(:collection) { create(:ai_active_context_collection, number_of_partitions: 5) }

    where(:routing_value, :partition_number) do
      1 | 0
      2 | 1
      3 | 3
      4 | 2
      5 | 3
      6 | 3
      7 | 4
      8 | 4
      9 | 2
      10 | 2
    end

    with_them do
      it 'always returns the same partition for a routing value' do
        expect(collection.partition_for(routing_value)).to eq(partition_number)
      end
    end
  end

  describe '#update_metadata!' do
    context 'with valid metadata' do
      it 'updates the metadata with valid values' do
        expect(collection.metadata).to eq({})

        collection.update_metadata!(search_embedding_version: 2)

        expect(collection.reload.metadata).to eq({ 'search_embedding_version' => 2 })
      end

      it 'merges with existing metadata' do
        collection.update_metadata!(search_embedding_version: 3)
        collection.update_metadata!(search_embedding_version: 4)

        expect(collection.reload.metadata).to eq({ 'search_embedding_version' => 4 })
      end

      it 'supports updating indexing_embedding_versions' do
        collection.update_metadata!(indexing_embedding_versions: [1, 2, 3])

        expect(collection.reload.metadata).to eq({ 'indexing_embedding_versions' => [1, 2, 3] })
      end

      it 'supports updating both search_embedding_version and indexing_embedding_versions' do
        collection.update_metadata!({
          search_embedding_version: 5,
          indexing_embedding_versions: [6, 7, 8]
        })

        expect(collection.reload.metadata).to eq({
          'search_embedding_version' => 5,
          'indexing_embedding_versions' => [6, 7, 8]
        })
      end

      it 'upserts and keeps existing metadata' do
        collection.update_metadata!(search_embedding_version: 5)
        collection.update_metadata!(indexing_embedding_versions: [6, 7, 8])

        expect(collection.reload.metadata).to eq({
          'search_embedding_version' => 5,
          'indexing_embedding_versions' => [6, 7, 8]
        })
      end
    end

    context 'with invalid metadata' do
      it 'raises an error when validation fails' do
        expect { collection.update_metadata!(search_embedding_version: -1) }.to raise_error(ActiveRecord::RecordInvalid)
      end

      it 'does not change the metadata when validation fails' do
        collection.update_metadata!(search_embedding_version: 5)
        expect(collection.reload.metadata).to eq({ 'search_embedding_version' => 5 })

        expect { collection.update_metadata!(search_embedding_version: -1) }.to raise_error(ActiveRecord::RecordInvalid)
        expect(collection.reload.metadata).to eq({ 'search_embedding_version' => 5 })
      end
    end
  end

  describe 'jsonb_accessor' do
    it 'defines accessor methods for metadata fields' do
      expect(collection).to respond_to(:include_ref_fields)
      expect(collection).to respond_to(:indexing_embedding_versions)
      expect(collection).to respond_to(:search_embedding_version)
      expect(collection).to respond_to(:collection_class)
    end

    it 'persists all accessor values to the metadata column' do
      collection.include_ref_fields = true
      collection.indexing_embedding_versions = [1, 2]
      collection.search_embedding_version = 3
      collection.collection_class = 'MyClass'

      collection.save!

      expect(collection.reload.metadata).to include(
        'include_ref_fields' => true,
        'indexing_embedding_versions' => [1, 2],
        'search_embedding_version' => 3,
        'collection_class' => 'MyClass'
      )
    end
  end
end
