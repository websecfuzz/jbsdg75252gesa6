# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Code::RepositoryIndexWorker, feature_category: :global_search do
  let(:worker) { described_class.new }

  describe '#perform' do
    let_it_be(:repository) { create(:ai_active_context_code_repository, state: :pending) }

    before do
      allow(::Ai::ActiveContext::Collections::Code).to receive(:indexing?).and_return(true)
      allow(Ai::ActiveContext::Code::InitialIndexingService).to receive(:execute)
    end

    context 'when ActiveContext indexing is enabled' do
      context 'with a valid pending repository' do
        it 'calls InitialIndexingService.execute with the repository' do
          worker.perform(repository.id)

          expect(Ai::ActiveContext::Code::InitialIndexingService).to have_received(:execute).with(repository)
        end
      end

      context 'with a repository that is not pending' do
        let_it_be(:ready_repository) { create(:ai_active_context_code_repository, state: :ready) }

        it 'does not call InitialIndexingService.execute' do
          worker.perform(ready_repository.id)

          expect(Ai::ActiveContext::Code::InitialIndexingService).not_to have_received(:execute)
        end
      end

      context 'with a non-existent repository' do
        it 'does not call IndexingService.execute' do
          worker.perform(999999)

          expect(Ai::ActiveContext::Code::InitialIndexingService).not_to have_received(:execute)
        end
      end
    end

    context 'when indexing is disabled' do
      before do
        allow(::Ai::ActiveContext::Collections::Code).to receive(:indexing?).and_return(false)
      end

      it 'does not call InitialIndexingService.execute' do
        worker.perform(repository.id)

        expect(Ai::ActiveContext::Code::InitialIndexingService).not_to have_received(:execute)
      end
    end

    describe 'parallel execution' do
      include ExclusiveLeaseHelpers

      let(:lease_key) { "Ai::ActiveContext::Code::RepositoryIndexWorker/#{repository.id}" }

      before do
        stub_exclusive_lease_taken(lease_key, timeout: described_class::LEASE_TTL)
      end

      context 'when the lock is locked' do
        it 'does not run service' do
          expect(worker).to receive(:in_lock)
            .with(lease_key,
              ttl: described_class::LEASE_TTL,
              retries: described_class::LEASE_RETRIES,
              sleep_sec: described_class::LEASE_TRY_AFTER)

          expect(Ai::ActiveContext::Code::InitialIndexingService).not_to receive(:execute)

          worker.perform(repository.id)
        end

        it 'schedules a new job' do
          expect(worker).to receive(:in_lock)
            .with(lease_key,
              ttl: described_class::LEASE_TTL,
              retries: described_class::LEASE_RETRIES,
              sleep_sec: described_class::LEASE_TRY_AFTER)
            .and_raise(Gitlab::ExclusiveLeaseHelpers::FailedToObtainLockError)

          expect(described_class).to receive(:perform_in)
            .with(described_class::RETRY_IN_IF_LOCKED, repository.id)

          worker.perform(repository.id)
        end
      end
    end
  end
end
