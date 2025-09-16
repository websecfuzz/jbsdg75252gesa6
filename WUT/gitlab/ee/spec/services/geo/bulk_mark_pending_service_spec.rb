# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::BulkMarkPendingService, feature_category: :geo_replication do
  include EE::GeoHelpers
  include_context 'with geo registries shared context'

  with_them do
    context 'when there are no options' do
      let(:service) { described_class.new(registry_class.name) }

      it_behaves_like 'mark_one_batch_to_update_with_lease is using an exclusive lease guard'

      describe '#mark_one_batch_to_update_with_lease!' do
        before do
          # We reset the bulk mark update cursor to 0
          # so the service starts from the registry ID 0
          service.set_bulk_mark_update_cursor(0)
        end

        it 'marks registries as never attempted to sync' do
          records = [
            create(registry_factory, :started, last_synced_at: 9.hours.ago),
            create(registry_factory, :synced, last_synced_at: 1.hour.ago),
            create(registry_factory, :failed, last_synced_at: Time.current)
          ]

          service.mark_one_batch_to_update_with_lease!

          records.each do |record|
            expect(record.reload.state).to eq registry_class::STATE_VALUES[:pending]
            expect(record.last_synced_at).to be_nil
          end
        end
      end

      describe '#remaining_batches_to_bulk_update' do
        let(:max_running_jobs) { 1 }

        context 'when there are remaining batches for pending registries' do
          it 'returns the number of remaining batches' do
            create(registry_factory, :started, last_synced_at: 9.hours.ago)

            expect(service.remaining_batches_to_bulk_mark_update(max_batch_count: max_running_jobs)).to eq(1)
          end
        end

        context 'when there are not remaining batches for not pending registries' do
          it 'returns zero remaining batches' do
            create_list(registry_factory, 3)

            expect(service.remaining_batches_to_bulk_mark_update(max_batch_count: max_running_jobs)).to eq(0)
          end
        end
      end

      describe '#set_bulk_mark_pending_cursor' do
        let(:last_id_updated) { 100 }
        let(:bulk_mark_pending_redis_key) { "geo:latest_id_marked_as_pending:#{registry_class.table_name}" }

        it 'sets redis shared state cursor key' do
          service.set_bulk_mark_update_cursor(last_id_updated)

          expect(service.send(:get_bulk_mark_update_cursor)).to eq(100)
        end
      end
    end

    context 'when there are options' do
      describe '#mark_one_batch_to_update_with_lease!' do
        it 'marks replication failed registries as never attempted to sync' do
          service = described_class.new(registry_class.name, { 'replication_state' => 'failed' })
          service.set_bulk_mark_update_cursor(0)
          records = {
            started: create(registry_factory, :started, last_synced_at: 9.hours.ago),
            synced: create(registry_factory, :synced, last_synced_at: 1.hour.ago),
            failed: create(registry_factory, :failed, last_synced_at: Time.current)
          }

          service.mark_one_batch_to_update_with_lease!

          expect(records[:failed].reload.state).to eq registry_class::STATE_VALUES[:pending]
          expect(records[:failed].last_synced_at).to be_nil

          expect(records[:started].reload.state).to eq registry_class::STATE_VALUES[:started]
          expect(records[:synced].reload.state).to eq registry_class::STATE_VALUES[:synced]
        end

        it 'marks selected IDs registries as never attempted to sync' do
          records = {
            started: create(registry_factory, :started, last_synced_at: 9.hours.ago),
            synced: create(registry_factory, :synced, last_synced_at: 1.hour.ago),
            failed: create(registry_factory, :failed, last_synced_at: Time.current)
          }
          service = described_class.new(registry_class.name, { 'ids' => [records[:started].id, records[:synced].id] })
          service.set_bulk_mark_update_cursor(0)

          service.mark_one_batch_to_update_with_lease!

          expect(records[:failed].reload.state).to eq registry_class::STATE_VALUES[:failed]

          expect(records[:started].reload.state).to eq registry_class::STATE_VALUES[:pending]
          expect(records[:started].last_synced_at).to be_nil
          expect(records[:synced].reload.state).to eq registry_class::STATE_VALUES[:pending]
          expect(records[:synced].last_synced_at).to be_nil
        end

        it 'marks replication failed registries as never attempted to sync' do
          stub_current_geo_node(create(:geo_node, :primary))
          stub_primary_site

          service = described_class.new(registry_class.name, { 'verification_state' => 'verification_failed' })
          service.set_bulk_mark_update_cursor(0)
          records = {
            fail1: create(registry_factory, :verification_failed, last_synced_at: 9.hours.ago),
            fail2: create(registry_factory, :verification_failed, last_synced_at: 1.hour.ago),
            synced: create(registry_factory, :verification_succeeded, last_synced_at: Time.current)
          }

          service.mark_one_batch_to_update_with_lease!

          if registry_class.replicator_class.verification_enabled?
            expect(records[:fail1].reload.state).to eq registry_class::STATE_VALUES[:pending]
            expect(records[:fail1].last_synced_at).to be_nil
            expect(records[:fail2].reload.state).to eq registry_class::STATE_VALUES[:pending]
            expect(records[:fail2].last_synced_at).to be_nil

            expect(records[:synced].reload.state).to eq registry_class::STATE_VALUES[:synced]
          else
            # no change
            expect(records[:fail1].reload).to eq records[:fail1]
            expect(records[:fail2].reload).to eq records[:fail2]
            expect(records[:synced].reload).to eq records[:synced]
          end
        end

        it 'marks selected registries from multiple parameters as never attempted to sync' do
          records = {
            started: create(registry_factory, :started, last_synced_at: 9.hours.ago),
            synced: create(registry_factory, :synced, last_synced_at: 1.hour.ago),
            failed: create(registry_factory, :failed, last_synced_at: Time.current)
          }
          service = described_class.new(
            registry_class.name,
            { 'ids' => [records[:started].id, records[:failed].id], 'replication_state' => 'failed' }
          )
          service.set_bulk_mark_update_cursor(0)

          service.mark_one_batch_to_update_with_lease!

          expect(records[:failed].reload.state).to eq registry_class::STATE_VALUES[:pending]
          expect(records[:failed].last_synced_at).to be_nil

          expect(records[:started].reload.state).to eq registry_class::STATE_VALUES[:started]
          expect(records[:synced].reload.state).to eq registry_class::STATE_VALUES[:synced]
        end
      end
    end
  end
end
