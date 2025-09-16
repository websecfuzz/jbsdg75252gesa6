# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::BulkProcessWorker, type: :worker, feature_category: :global_search do
  let(:worker) { described_class.new }

  it_behaves_like 'an idempotent worker' do
    let(:job_args) { ['Ai::Context::TestQueue', 1] }
  end

  it { is_expected.to be_a(ApplicationWorker) }
  it { is_expected.to be_a(CronjobQueue) }
  it { is_expected.to be_a(Search::Worker) }

  describe '#perform' do
    let(:queue_class_name) { 'Ai::Context::TestQueue' }
    let(:shard) { 1 }

    before do
      stub_const(queue_class_name, Ai::Context::TestQueue)
      allow(ActiveContext).to receive(:indexing?).and_return(true)
      allow(worker).to receive(:in_lock).and_yield
    end

    context 'when indexing is disabled' do
      before do
        allow(ActiveContext).to receive(:indexing?).and_return(false)
      end

      it 'returns false' do
        expect(worker.perform).to be false
      end
    end

    context 'when no arguments are provided' do
      it 'enqueues all shards' do
        expect(described_class).to receive(:bulk_perform_async_with_contexts)
        worker.perform
      end
    end

    context 'when arguments are provided' do
      it 'processes the shard' do
        expect(worker).to receive(:process_shard).with(Ai::Context::TestQueue, shard)
        worker.perform(queue_class_name, shard)
      end

      it 'handles FailedToObtainLockError' do
        allow(worker).to receive(:process_shard).and_raise(Gitlab::ExclusiveLeaseHelpers::FailedToObtainLockError)
        expect { worker.perform(queue_class_name, shard) }.not_to raise_error
      end
    end
  end

  describe '#process_shard' do
    let(:queue) { instance_double(Ai::Context::TestQueue, shard: 1, redis_key: 'test_queue:1') }
    let(:shard) { 1 }

    before do
      allow(worker).to receive(:in_lock).and_yield
      allow(ActiveContext::BulkProcessQueue).to receive(:process!).and_return([10, 0])
    end

    it 'processes the queue and logs metadata' do
      expect(worker).to receive(:log_extra_metadata_on_done).with(:records_count, 10)
      expect(worker).to receive(:log_extra_metadata_on_done).with(:shard_number, shard)
      worker.process_shard(queue, shard)
    end

    context 'when re-enqueue conditions are met' do
      before do
        allow(ActiveContext::Config).to receive(:re_enqueue_indexing_workers?).and_return(true)
      end

      it 're-enqueues the shard' do
        expect(described_class).to receive(:perform_in)
        worker.process_shard(queue, shard)
      end
    end

    context 'when re-enqueue conditions are not met' do
      before do
        allow(ActiveContext::Config).to receive(:re_enqueue_indexing_workers?).and_return(false)
      end

      it 'does not re-enqueue the shard' do
        expect(described_class).not_to receive(:perform_in)
        worker.process_shard(queue, shard)
      end
    end
  end

  describe '#should_re_enqueue?' do
    it 'returns true when conditions are met' do
      allow(ActiveContext::Config).to receive(:re_enqueue_indexing_workers?).and_return(true)
      expect(worker.should_re_enqueue?(10, 0)).to be true
    end

    it 'returns false when records_count is zero' do
      expect(worker.should_re_enqueue?(0, 0)).to be false
    end

    it 'returns false when failures_count is positive' do
      expect(worker.should_re_enqueue?(10, 1)).to be false
    end

    it 'returns false when re-enqueue is disabled' do
      allow(ActiveContext::Config).to receive(:re_enqueue_indexing_workers?).and_return(false)
      expect(worker.should_re_enqueue?(10, 0)).to be false
    end
  end
end

module Ai
  module Context
    TestQueue = Struct.new(:shard) do
      def redis_key
        "test_queue:#{shard}"
      end
    end
  end
end
