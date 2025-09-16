# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::BulkMarkVerificationPendingService, feature_category: :geo_replication do
  include EE::GeoHelpers
  include_context 'with geo registries shared context'

  let(:service) { described_class.new(registry_class.name, options) }

  with_them do
    context 'when there are no options' do
      let(:options) { {} }

      it_behaves_like 'mark_one_batch_to_update_with_lease is using an exclusive lease guard'

      describe '#mark_one_batch_to_update_with_lease!' do
        before do
          # We reset the bulk mark update cursor to 0
          # so the service starts from the registry ID 0
          service.set_bulk_mark_update_cursor(0)
        end

        it 'marks registries as they need verification' do
          records = [
            create(
              registry_factory,
              :synced,
              verification_state: registry_class.verification_state_value(:verification_failed),
              verification_failure: 'Failed reason',
              verified_at: Time.current
            ),
            create(
              registry_factory,
              :synced,
              verification_state: registry_class.verification_state_value(:verification_succeeded),
              verification_checksum: 'abc123',
              verified_at: Time.current
            ),
            create(
              registry_factory,
              :synced,
              verification_state: registry_class.verification_state_value(:verification_started),
              verified_at: Time.current
            )
          ]

          service.mark_one_batch_to_update_with_lease!

          records.each do |record|
            expect(record.reload.verification_state)
              .to eq registry_class::VERIFICATION_STATE_VALUES[:verification_pending]
          end
        end
      end

      describe '#remaining_batches_to_bulk_mark_update' do
        let(:max_running_jobs) { 1 }

        context 'when there are remaining batches for registries with verification pending' do
          it 'returns the number of remaining batches' do
            create(
              registry_factory,
              :synced,
              verification_state: registry_class.verification_state_value(:verification_started)
            )

            expect(service.remaining_batches_to_bulk_mark_update(max_batch_count: max_running_jobs))
              .to eq(1)
          end
        end

        context 'when there are not remaining batches for registries with verification not pending' do
          it 'returns zero remaining batches' do
            create_list(
              registry_factory,
              3,
              :synced,
              verification_state: registry_class.verification_state_value(:verification_pending)
            )

            expect(service.remaining_batches_to_bulk_mark_update(max_batch_count: max_running_jobs))
              .to eq(0)
          end
        end
      end

      describe '#set_bulk_mark_update_cursor' do
        let(:last_id_updated) { 100 }
        let(:bulk_mark_pending_redis_key) do
          "geo:latest_id_marked_as_verification_pending:#{registry_class.table_name}"
        end

        it 'sets redis shared state cursor key' do
          service.set_bulk_mark_update_cursor(last_id_updated)

          expect(service.send(:get_bulk_mark_update_cursor)).to eq(100)
        end
      end
    end

    context 'when there are options' do
      let(:success_value) { registry_class::VERIFICATION_STATE_VALUES[:verification_succeeded] }
      let(:pending_value) { registry_class::VERIFICATION_STATE_VALUES[:verification_pending] }
      let(:failed_value) { registry_class::VERIFICATION_STATE_VALUES[:verification_failed] }

      describe '#mark_one_batch_to_update_with_lease!!' do
        before do
          service.set_bulk_mark_update_cursor(0)
        end

        context 'when filtering based on replication failed' do
          let(:options) { { 'replication_state' => 'failed' } }
          let(:started) { create(registry_factory, :started) }
          let(:synced) { create(registry_factory, :verification_succeeded) }
          let(:failed) { create(registry_factory, :failed) }

          it 'marks registries as verification pending' do
            service.mark_one_batch_to_update_with_lease!

            expect(failed.reload.verification_state).to eq pending_value

            # no change
            expect(started.reload).to eq started
            expect(synced.reload).to eq synced
          end
        end

        context 'when filtering based on IDs' do
          let(:started) { create(registry_factory, :verification_succeeded) }
          let(:synced) { create(registry_factory, :verification_succeeded) }
          let(:failed) { create(registry_factory, :verification_failed) }
          let(:options) { { 'ids' => [started.id, synced.id] } }

          it 'marks registries as verification pending' do
            service.mark_one_batch_to_update_with_lease!

            expect(failed.reload.verification_state).to eq failed_value

            expect(started.reload.verification_state).to eq pending_value
            expect(synced.reload.verification_state).to eq pending_value
          end
        end

        context 'when filtering based on verification state' do
          let(:options) { { 'verification_state' => 'verification_failed' } }

          context 'when verification is disabled' do
            before do
              allow(registry_class.replicator_class).to receive(:verification_enabled?).and_return(false)
            end

            it 'leaves records unchanged' do
              verification_failed1 = create(registry_factory, :verification_failed)
              verification_failed2 = create(registry_factory, :verification_failed)
              verification_failed3 = create(registry_factory, :verification_failed)

              service.mark_one_batch_to_update_with_lease!

              expect(verification_failed1.reload).to eq verification_failed1
              expect(verification_failed2.reload).to eq verification_failed2
              expect(verification_failed3.reload).to eq verification_failed3
            end
          end

          context 'when verification is enabled' do
            before do
              allow(registry_class.replicator_class).to receive(:verification_enabled?).and_return(true)
            end

            it 'marks registries as verification pending' do
              verification_failed = create(registry_factory, :verification_failed)
              verification_failed_agn = create(registry_factory, :verification_failed)
              replication_failed = create(registry_factory, :failed)

              service.mark_one_batch_to_update_with_lease!

              expect(verification_failed.reload.verification_state).to eq pending_value
              expect(verification_failed_agn.reload.verification_state).to eq pending_value

              expect(replication_failed.reload).to eq replication_failed
            end
          end
        end

        context 'when filtering based on multiple parameters' do
          let(:success) { create(registry_factory, :verification_succeeded) }
          let(:synced) { create(registry_factory, :verification_succeeded) }
          let(:failed) { create(registry_factory, :failed) }
          let(:options) { { 'ids' => [success.id, failed.id], 'replication_state' => 'synced' } }

          it 'marks registries as verification pending' do
            service.mark_one_batch_to_update_with_lease!

            expect(success.reload.verification_state).to eq pending_value

            expect(failed.reload).to eq failed
            expect(synced.reload).to eq synced
          end
        end
      end
    end
  end
end
