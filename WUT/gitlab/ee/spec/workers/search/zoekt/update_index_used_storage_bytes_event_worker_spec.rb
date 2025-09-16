# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::UpdateIndexUsedStorageBytesEventWorker, feature_category: :global_search do
  let(:event) { Search::Zoekt::UpdateIndexUsedStorageBytesEvent.new(data: {}) }
  let(:time) { Time.zone.now }

  # Stale | Correct used_storage_bytes should be 3*20
  let_it_be_with_reload(:idx) do
    create(:zoekt_index, :stale_used_storage_bytes_updated_at, used_storage_bytes: 10)
  end

  # Stale | Correct used_storage_bytes should be 3*20
  let_it_be_with_reload(:idx2) { create(:zoekt_index, used_storage_bytes: 10) }

  # Stale | Correct used_storage_bytes should be default_used_storage_bytes
  let_it_be_with_reload(:idx_empty_repos) do
    create(:zoekt_index, :stale_used_storage_bytes_updated_at)
  end

  # Stale | Correct used_storage_bytes should be default_used_storage_bytes
  let_it_be_with_reload(:idx_without_repos) do
    create(:zoekt_index, :stale_used_storage_bytes_updated_at)
  end

  # Stale | Correct used_storage_bytes should be 3*30
  let_it_be_with_reload(:idx_correct_used_storage_bytes) do
    create(:zoekt_index, :stale_used_storage_bytes_updated_at, used_storage_bytes: 90)
  end

  # Not Stale | Correct used_storage_bytes should be 3*20
  let_it_be_with_reload(:idx_out_of_scope) do
    create(:zoekt_index, used_storage_bytes: 10, last_indexed_at: 1.minute.ago,
      used_storage_bytes_updated_at: Time.zone.now)
  end

  let(:indices) { [idx, idx2, idx_empty_repos, idx_without_repos, idx_correct_used_storage_bytes, idx_out_of_scope] }
  let(:default_used_storage_bytes) { Search::Zoekt::Index::DEFAULT_USED_STORAGE_BYTES }

  before_all do
    create_list(:zoekt_repository, 3, zoekt_index: idx, size_bytes: 20)
    create_list(:zoekt_repository, 3, zoekt_index: idx2, size_bytes: 20)
    create_list(:zoekt_repository, 3, zoekt_index: idx_empty_repos, size_bytes: 0)
    create_list(:zoekt_repository, 3, zoekt_index: idx_correct_used_storage_bytes, size_bytes: 30)
    create_list(:zoekt_repository, 3, zoekt_index: idx_out_of_scope, size_bytes: 20)
  end

  it_behaves_like 'subscribes to event'

  it_behaves_like 'an idempotent worker', :freeze_time do
    it 'updates used_storage_bytes of indices which are the part of with_stale_used_storage_bytes_updated_at' do
      expect(indices.map { |i| i.reload.used_storage_bytes }).to eq [10, 10, 0, 0, 90, 10]
      consume_event(subscriber: described_class, event: event)
      expected = [60, 60, default_used_storage_bytes, default_used_storage_bytes, 90, 10]
      expect(indices.map { |i| i.reload.used_storage_bytes }).to eq expected
    end

    context 'when there are more indices than the batch size' do
      before do
        stub_const("#{described_class}::BATCH_SIZE", 2)
      end

      it 'updates used_storage_bytes by order of when they were last updated' do
        older_time = 3.days.ago
        middle_time = 2.days.ago
        newer_time = 1.day.ago

        idx.update!(used_storage_bytes_updated_at: older_time)
        idx2.update!(used_storage_bytes_updated_at: middle_time)
        idx_correct_used_storage_bytes.update!(used_storage_bytes_updated_at: newer_time)

        expect(indices.map { |i| i.reload.used_storage_bytes }).to eq [10, 10, 0, 0, 90, 10]
        consume_event(subscriber: described_class, event: event)

        expected = [60, 10, 0, 0, 90, 10]
        expect(indices.map { |i| i.reload.used_storage_bytes }).to eq expected

        consume_event(subscriber: described_class, event: event)
        expected = [60, 10, default_used_storage_bytes, default_used_storage_bytes, 90, 10]
        expect(indices.map { |i| i.reload.used_storage_bytes }).to eq expected
      end

      it 'processes only up to the batch size and schedules another event' do
        expect(Gitlab::EventStore).to receive(:publish).with(
          an_object_having_attributes(class: Search::Zoekt::UpdateIndexUsedStorageBytesEvent, data: {})
        )

        expect do
          consume_event(subscriber: described_class, event: event)
        end.to change { Search::Zoekt::Index.with_stale_used_storage_bytes_updated_at.count }.by(-2)
      end
    end
  end
end
