# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::ForceUpdateOverprovisionedIndexEventWorker, feature_category: :global_search do
  let(:event) { Search::Zoekt::ForceUpdateOverprovisionedIndexEvent.new(data: {}) }

  # pending | stale_updated_used_storage_bytes | overprovisioned
  let_it_be_with_reload(:idx) do
    create(:zoekt_index, :stale_used_storage_bytes_updated_at, watermark_level: :overprovisioned)
  end

  # ready | overprovisioned | latest_used_storage_bytes
  let_it_be_with_reload(:idx2) { create(:zoekt_index, :ready, :overprovisioned, :latest_used_storage_bytes) }
  let_it_be_with_reload(:idx3) { create(:zoekt_index, :ready, :overprovisioned, :latest_used_storage_bytes) }
  let_it_be_with_reload(:idx4) { create(:zoekt_index, :ready, :overprovisioned, :latest_used_storage_bytes) }

  # pending | overprovisioned | latest_used_storage_bytes
  let_it_be_with_reload(:idx5) { create(:zoekt_index, :overprovisioned, :latest_used_storage_bytes) }

  # ready | low_watermark_exceeded | latest_used_storage_bytes
  let_it_be_with_reload(:idx6) { create(:zoekt_index, :ready, :low_watermark_exceeded, :latest_used_storage_bytes) }

  before_all do
    create_list(:zoekt_repository, 3, zoekt_index: idx2, size_bytes: 20)
  end

  it_behaves_like 'subscribes to event'

  it_behaves_like 'an idempotent worker', :freeze_time do
    it 'updates reserved_storage_bytes of overprovisioned ready indices whose used_storage_bytes is latest' do
      idx2_initial_reserved_storage_bytes = idx2.reserved_storage_bytes
      idx3_initial_reserved_storage_bytes = idx3.reserved_storage_bytes
      idx4_initial_reserved_storage_bytes = idx4.reserved_storage_bytes
      expect { consume_event(subscriber: described_class, event: event) }
        .to not_publish_event(Search::Zoekt::ForceUpdateOverprovisionedIndexEvent)
      expect(idx.reload).to be_overprovisioned
      expect([idx2.reload, idx3.reload, idx4.reload].all?(&:healthy?)).to be true
      expect(idx2.reserved_storage_bytes).to be < idx2_initial_reserved_storage_bytes
      expect(idx3.reserved_storage_bytes).to be < idx3_initial_reserved_storage_bytes
      expect(idx4.reserved_storage_bytes).to be < idx4_initial_reserved_storage_bytes
      expect(idx5.reload).to be_overprovisioned
      expect(idx6.reload).to be_low_watermark_exceeded
      expect(Search::Zoekt::Index.overprovisioned.ready.with_latest_used_storage_bytes_updated_at).to be_empty
    end

    context 'when there are more indices than the batch size' do
      before do
        stub_const("#{described_class}::BATCH_SIZE", 2)
      end

      it 'processes only up to the batch size and schedules another event' do
        expect { consume_event(subscriber: described_class, event: event) }
          .to publish_event(Search::Zoekt::ForceUpdateOverprovisionedIndexEvent)
        expect(Search::Zoekt::Index.overprovisioned.ready.with_latest_used_storage_bytes_updated_at).not_to be_empty
      end
    end
  end
end
