# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::MigrationWorker, :clean_gitlab_redis_shared_state, type: :worker, feature_category: :global_search do
  include ExclusiveLeaseHelpers

  let(:worker) { described_class.new }
  let!(:connection) { create(:ai_active_context_connection, active: true) }
  let(:adapter) { double }
  let(:migration_path) do
    Rails.root.join('ee/spec/fixtures/ai/active_context/migrations/20240101010101_create_projects.rb')
  end

  subject(:perform) { worker.perform }

  before do
    allow(ActiveContext).to receive(:adapter).and_return(adapter)
    allow(ActiveContext::Config).to receive_messages(
      indexing_enabled?: true,
      migrations_path: migration_path,
      logger: Rails.logger,
      enabled?: true
    )
    allow(adapter).to receive_messages(
      connection: connection,
      executor: double
    )
  end

  describe '#perform' do
    context 'when preflight checks fail' do
      context 'when indexing is disabled' do
        before do
          allow(ActiveContext::Config).to receive(:indexing_enabled?).and_return(false)
        end

        it 'does not process migrations' do
          expect(worker).not_to receive(:execute_current_migration)

          expect(perform).to be false
        end
      end

      context 'when adapter is not configured' do
        before do
          allow(ActiveContext).to receive(:adapter).and_return(nil)
        end

        it 'does not process migrations' do
          expect(worker).not_to receive(:execute_current_migration)

          expect(perform).to be false
        end
      end
    end

    context 'when there are failed migrations' do
      let!(:failed_migration) { create(:ai_active_context_migration, connection: connection, status: :failed) }

      it 'exits without processing migrations' do
        expect(worker).not_to receive(:execute_current_migration)

        perform
      end
    end

    context 'with valid configuration' do
      let(:dictionary_instance) { instance_double(ActiveContext::Migration::Dictionary) }
      let(:migration_versions) { %w[20240101010101 20240101010102] }

      before do
        allow(ActiveContext::Migration::Dictionary).to receive(:instance).and_return(dictionary_instance)
        allow(dictionary_instance).to receive(:migrations).with(versions_only: true).and_return(migration_versions)
        allow(dictionary_instance).to receive(:find_by_version)
      end

      it 'creates missing migration records' do
        expect(Ai::ActiveContext::Migration).to receive(:create!)
          .with(connection: connection, version: '20240101010101')
        expect(Ai::ActiveContext::Migration).to receive(:create!)
          .with(connection: connection, version: '20240101010102')

        perform
      end

      context 'when there are orphaned migration records' do
        let!(:orphaned_migration) do
          create(:ai_active_context_migration, connection: connection, version: '20230101010101')
        end

        it 'deletes orphaned migration records' do
          expect { perform }.to change {
            Ai::ActiveContext::Migration.exists?(id: orphaned_migration.id)
          }.from(true).to(false)
        end
      end

      context 'when there is a pending migration' do
        let(:migration_class) { Class.new(ActiveContext::Migration::V1_0) }
        let(:migration_instance) { instance_double(migration_class) }
        let!(:pending_migration) do
          create(:ai_active_context_migration, connection: connection, version: '20240101010101', status: :pending)
        end

        before do
          allow(dictionary_instance).to receive(:find_by_version).with('20240101010101').and_return(migration_class)
          allow(migration_class).to receive(:new).and_return(migration_instance)
          allow(migration_instance).to receive(:migrate!)
        end

        context 'when all operations are completed' do
          before do
            allow(migration_instance).to receive(:all_operations_completed?).and_return(true)
          end

          it 'marks the migration as completed' do
            perform

            expect(pending_migration.reload).to be_completed
          end
        end

        context 'when not all operations are completed' do
          before do
            allow(migration_instance).to receive(:all_operations_completed?).and_return(false)
          end

          it 're-enqueues the worker' do
            expect(described_class).to receive(:perform_in).with(30.seconds)

            perform
          end

          it 'does not mark the migration as completed' do
            perform

            expect(pending_migration.reload).not_to be_completed
            expect(pending_migration.reload).to be_in_progress
          end
        end

        context 'when the migration fails' do
          let(:error) { StandardError.new('Something went wrong') }

          before do
            allow(migration_instance).to receive(:migrate!).and_raise(error)
          end

          it 'decreases retries left' do
            expect { perform }.to change { pending_migration.reload.retries_left }.from(3).to(2)
          end

          context 'when no retries are left' do
            before do
              pending_migration.update!(retries_left: 1)
            end

            it 'marks the migration as failed' do
              perform

              expect(pending_migration.reload).to be_failed
              expect(pending_migration.reload.error_message).to include('Something went wrong')
            end
          end
        end
      end

      context 'when there are no pending migrations' do
        it 'does nothing' do
          expect(perform).to be true
        end
      end
    end
  end
end
