# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Collections::Code, feature_category: :code_suggestions do
  let_it_be(:collection) { create(:ai_active_context_collection, name: described_class.collection_name) }

  before do
    allow(described_class).to receive(:collection_record).and_return(collection)
  end

  describe '.indexing?' do
    it 'returns false when indexing is disabled' do
      allow(ActiveContext).to receive(:indexing?).and_return(false)

      expect(described_class.indexing?).to be(false)
    end

    it 'returns false when ActiveContext migration is not complete' do
      allow(ActiveContext).to receive(:indexing?).and_return(true)
      allow(Ai::ActiveContext::Migration).to receive(:complete?).and_return(false)

      expect(described_class.indexing?).to be(false)
    end

    it 'returns true when indexing is enabled and migration is complete' do
      allow(ActiveContext).to receive(:indexing?).and_return(true)
      allow(Ai::ActiveContext::Migration).to receive(:complete?).and_return(true)

      expect(described_class.indexing?).to be(true)
    end
  end

  describe '.track_refs!' do
    it 'tracks each hash with the routing' do
      routing = '123'
      hashes = %w[hash1 hash2 hash3]

      hashes.each do |hash|
        expect(described_class).to receive(:track!).with({ id: hash, routing: routing })
      end

      described_class.track_refs!(routing: routing, hashes: hashes)
    end
  end

  describe '.track!' do
    let(:id) { 'hash' }
    let(:routing) { '123' }

    it 'enqueues an object correctly' do
      described_class.track!({ id: id, routing: routing })

      queued_items = ActiveContext::Queues.all_queued_items.values.flatten
      expect(queued_items.count).to eq(1)
      expect(queued_items.first).to eq("Ai::ActiveContext::References::Code|#{collection.reload.id}|#{routing}|#{id}")
    end

    context 'when collection record is not found' do
      before do
        allow(described_class).to receive(:collection_record).and_return(nil)
      end

      it 'raises an error' do
        expect { described_class.track!({ id: id, routing: routing }) }
          .to raise_error(StandardError, /expected to have a collection record/)
      end
    end
  end

  describe '.redact_unauthorized_results!' do
    let_it_be(:user) { create(:user) }
    let_it_be(:project_1) { create(:project, owners: [user]) }
    let_it_be(:project_2) { create(:project, owners: [user]) }
    let_it_be(:unauthorized_project) { create(:project) }

    let(:hit_1) { { 'id' => 1, 'project_id' => project_1.id, 'content' => 'test content 1' } }
    let(:hit_2) { { 'id' => 2, 'project_id' => project_2.id, 'content' => 'test content 2' } }
    let(:hit_3) { { 'id' => 3, 'project_id' => unauthorized_project.id, 'content' => 'test content 3' } }
    let(:elasticsearch_result) do
      {
        'hits' => {
          'total' => { 'value' => 2 },
          'hits' => [
            { '_source' => hit_1 },
            { '_source' => hit_2 },
            { '_source' => hit_3 }
          ]
        }
      }
    end

    let(:result) do
      ActiveContext::Databases::Elasticsearch::QueryResult.new(
        result: elasticsearch_result,
        collection: collection,
        user: user
      )
    end

    it 'includes results for projects accessible to the user' do
      new_result = described_class.redact_unauthorized_results!(result)
      expect(new_result.pluck('id')).to eq([hit_1['id'], hit_2['id']])
    end

    context 'when project is not found' do
      before do
        project_2.delete
      end

      it 'excludes results for the project' do
        new_result = described_class.redact_unauthorized_results!(result)
        expect(new_result.pluck('id')).to eq([hit_1['id']])
      end
    end

    context 'when user is nil' do
      let(:user) { nil }

      it 'returns the original result without filtering' do
        expect(described_class.redact_unauthorized_results!(result)).to eq(result)
      end
    end
  end

  describe '.current_indexing_embedding_versions' do
    it 'is empty' do
      expect(described_class.current_indexing_embedding_versions).to be_empty
    end

    context 'when collection has indexing_embedding_versions set to [1]' do
      before do
        collection.update!(indexing_embedding_versions: [1])
      end

      it 'returns the matching hash from MODEL' do
        expect(described_class.current_indexing_embedding_versions).to eq([described_class::MODELS[1]])
      end
    end
  end

  describe '.current_search_embedding_version' do
    it 'is empty' do
      expect(described_class.current_search_embedding_version).to be_empty
    end

    context 'when collection has current_search_embedding_version set to 1' do
      before do
        collection.update!(search_embedding_version: 1)
      end

      it 'returns the matching hash from MODEL' do
        expect(described_class.current_search_embedding_version).to eq(described_class::MODELS[1])
      end
    end
  end

  describe '.partition_name' do
    it 'is the collection name' do
      expect(described_class.partition_name).to eq(collection.name)
    end
  end

  describe '.partition_number' do
    it 'is calculated from collection.partition_for' do
      expect(collection).to receive(:partition_for).with('something')

      described_class.partition_number('something')
    end
  end
end
