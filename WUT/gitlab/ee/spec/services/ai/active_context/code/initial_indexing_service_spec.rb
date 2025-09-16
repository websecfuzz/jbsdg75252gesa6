# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Code::InitialIndexingService, feature_category: :global_search do
  let_it_be(:repository) { create(:ai_active_context_code_repository, state: :pending) }
  let_it_be(:collection) { create(:ai_active_context_collection) }

  before do
    allow(ActiveContext::CollectionCache).to receive(:fetch).and_return(collection)
  end

  describe '.execute' do
    subject(:execute) { described_class.execute(repository) }

    it 'calls the indexer to get ids and then tracks refs for the ids' do
      expect(repository.reload.state).to eq('pending')

      expect(Ai::ActiveContext::Code::Indexer).to receive(:run!)
        .with(repository).and_return(%w[hash1 hash2])

      expect(::Ai::ActiveContext::Collections::Code).to receive(:track_refs!)
        .with(hashes: %w[hash1 hash2], routing: repository.project_id)

      execute

      expect(repository.reload.state).to eq('embedding_indexing_in_progress')
      expect(repository.initial_indexing_last_queued_item).to eq('hash2')
    end

    context 'when indexing fails' do
      let(:error) { StandardError.new('Indexing failed') }

      before do
        allow(Ai::ActiveContext::Code::Indexer).to receive(:run!).and_raise(error)
      end

      it 'sets the repository to failed and passes the error on' do
        expect { execute }.to raise_error(error)

        expect(repository.reload.state).to eq('failed')
        expect(repository.last_error).to eq(error.message)
      end
    end
  end
end
