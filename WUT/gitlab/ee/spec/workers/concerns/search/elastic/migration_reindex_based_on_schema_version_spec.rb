# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::MigrationReindexBasedOnSchemaVersion, feature_category: :global_search do
  context 'when required methods are not implemented' do
    let(:migration_klass) do
      Class.new do
        include ::Search::Elastic::MigrationReindexBasedOnSchemaVersion
      end
    end

    subject(:migration) { migration_klass.new }

    describe '#query_batch_size' do
      it 'raises a NotImplementedError when batch_size is not defined' do
        expect { migration.send(:query_batch_size) }.to raise_error(NotImplementedError)
      end
    end

    describe '#index_name' do
      it 'raises a NotImplementedError when DOCUMENT_TYPE is not defined' do
        expect { migration.send(:index_name) }.to raise_error(NotImplementedError)
      end
    end
  end

  context 'with a properly implemented migration class' do
    let(:version) { 30231204134928 }
    let(:new_schema_version) { 2 }
    let(:document_type) { WorkItem }

    let(:client) { Elasticsearch::Client }
    let(:helper) { ::Gitlab::Elastic::Helper.default }

    let(:migration_klass) do
      migration_klass = Class.new(Elastic::Migration) do
        include ::Search::Elastic::MigrationReindexBasedOnSchemaVersion

        batch_size 100
        batched!
        throttle_delay 1.minute
        retry_on_failure
      end

      stub_const('MigrationKlass', migration_klass)

      MigrationKlass
    end

    subject(:migration) { MigrationKlass.new(version) }

    before do
      migration_klass.const_set(:DOCUMENT_TYPE, WorkItem)
      migration_klass.const_set(:NEW_SCHEMA_VERSION, 2)

      allow(migration).to receive_messages(client: client, helper: helper, index_name: 'test-index')
      allow(migration).to receive(:set_migration_state)
      allow(::Gitlab::Elastic::Helper).to receive(:default).and_return(helper)
      allow(helper).to receive(:refresh_index)
    end

    describe '#completed?' do
      it 'returns true when no documents with old schema version remain' do
        expect(client).to receive(:count).and_return({ 'count' => 0 })

        expect(migration.completed?).to be(true)
      end

      it 'returns false when documents with old schema version remain' do
        expect(client).to receive(:count).and_return({ 'count' => 10 })

        expect(migration.completed?).to be(false)
      end

      it 'sets migration state with remaining document count' do
        expect(client).to receive(:count).and_return({ 'count' => 5 })
        expect(migration).to receive(:set_migration_state).with(documents_remaining: 5)

        migration.completed?
      end
    end

    describe '#migrate' do
      context 'when migration is already completed' do
        before do
          allow(migration).to receive(:completed?).and_return(true)
        end

        it 'skips reindexing' do
          expect(migration).not_to receive(:process_batch!)

          migration.migrate
        end
      end

      context 'when queue is full' do
        before do
          allow(migration).to receive_messages(completed?: false, queue_full?: true)
        end

        it 'skips reindexing due to throttling' do
          expect(migration).not_to receive(:process_batch!)

          migration.migrate
        end
      end

      context 'when migration can proceed' do
        let(:document_references) { [Search::Elastic::References::WorkItem] }

        before do
          allow(migration).to receive_messages(completed?: false, queue_full?: false,
            process_batch!: document_references)
        end

        it 'processes a batch of documents' do
          expect(migration).to receive(:process_batch!)

          migration.migrate
        end

        it 'logs the reindexing process' do
          expect(migration).to receive(:log).with('Start reindexing', hash_including(:index_name, :batch_size))
          expect(migration).to receive(:log)
            .with('Reindexing batch has been processed', hash_including(:index_name, :documents_count))

          migration.migrate
        end
      end

      context 'when an error occurs' do
        before do
          allow(migration).to receive_messages(completed?: false, queue_full?: false)
          allow(migration).to receive(:process_batch!).and_raise(StandardError.new("Test error"))
        end

        it 'logs the error and re-raises it' do
          expect(migration).to receive(:log_raise)
            .with('migrate failed', hash_including(:error_class, :error_message)).and_call_original

          expect { migration.migrate }.to raise_error(StandardError)
        end
      end
    end

    describe '#process_batch!' do
      let(:hits) do
        [
          { '_id' => 'es_id_1', '_routing' => 'parent_1', '_source' => { 'id' => 1 } },
          { '_id' => 'es_id_2', '_routing' => nil, '_source' => { 'id' => 2 } }
        ]
      end

      let(:search_results) do
        { 'hits' => { 'hits' => hits } }
      end

      before do
        allow(client).to receive(:search).and_return(search_results)
        allow(migration.send(:bookkeeping_service)).to receive(:track!)
      end

      it 'searches for documents with old schema version' do
        expect(client).to receive(:search).with(
          hash_including(
            index: 'test-index',
            body: hash_including(query: instance_of(Hash), size: instance_of(Integer))
          )
        )

        migration.send(:process_batch!)
      end

      it 'creates document references from search results' do
        expect(Search::Elastic::Reference).to receive(:init).with(document_type, 1, 'es_id_1', 'parent_1')
        expect(Search::Elastic::Reference).to receive(:init).with(document_type, 2, 'es_id_2', nil)

        migration.send(:process_batch!)
      end

      it 'tracks document references for reindexing' do
        expect(migration.send(:bookkeeping_service)).to receive(:track!).once

        migration.send(:process_batch!)
      end

      it 'returns the document references' do
        refs = migration.send(:process_batch!)

        expect(refs.size).to eq(2)
      end
    end

    describe '#bookkeeping_service' do
      it 'returns the ProcessInitialBookkeepingService' do
        expect(migration.send(:bookkeeping_service)).to eq(::Elastic::ProcessInitialBookkeepingService)
      end
    end

    describe '#queue_full?' do
      it 'returns true when queue size exceeds threshold' do
        allow(migration.send(:bookkeeping_service)).to receive(:queue_size)
          .and_return(described_class::QUEUE_THRESHOLD + 1)

        expect(migration.send(:queue_full?)).to be(true)
      end

      it 'returns false when queue size is below threshold' do
        allow(migration.send(:bookkeeping_service)).to receive(:queue_size)
          .and_return(described_class::QUEUE_THRESHOLD - 1)

        expect(migration.send(:queue_full?)).to be(false)
      end
    end

    describe '#update_batch_size' do
      it 'returns the class constant if defined' do
        update_size = 350
        migration_klass.const_set(:UPDATE_BATCH_SIZE, update_size)

        expect(migration.send(:update_batch_size)).to eq(update_size)
      end

      it 'returns the module constant if class constant is not defined' do
        expect(migration.send(:update_batch_size)).to eq(described_class::UPDATE_BATCH_SIZE)
      end
    end
  end

  describe 'integration tests', :elastic do
    let(:document_type) { WorkItem }
    let(:object) { :work_item }
    let(:current_schema_version) { ::Search::Elastic::References::WorkItem::SCHEMA_VERSION }

    let(:migration_klass) do
      migration_klass = Class.new(Elastic::Migration) do
        include ::Search::Elastic::MigrationReindexBasedOnSchemaVersion

        batch_size 100
        batched!
        throttle_delay 1.minute
        retry_on_failure
      end

      stub_const('MigrationKlass', migration_klass)

      MigrationKlass
    end

    let(:version) { 30231204134928 }
    let(:objects) { create_list(object, 3) }

    before do
      migration_klass.const_set(:DOCUMENT_TYPE, document_type)
    end

    subject(:migration) { MigrationKlass.new(version) }

    describe '#migrate' do
      before do
        stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
        set_elasticsearch_migration_to(version, including: false)

        migration.send(:bookkeeping_service).track!(*objects)
        ensure_elasticsearch_index!

        migration_record = Elastic::MigrationRecord.new(version: version, name: 'SomeName', filename: 'some_file')
        allow(Elastic::DataMigrationService).to receive(:[]).and_return(migration_record)
        migration.set_migration_state(current_id: 0)

        migration_klass.const_set(:NEW_SCHEMA_VERSION, current_schema_version + 1)
      end

      context 'when records exist with old schema' do
        it 'processes records' do
          # make sure new indexed records get the correct schema_version
          stub_const('Search::Elastic::References::WorkItem::SCHEMA_VERSION', current_schema_version + 1)

          expected_count = objects.size
          expect(migration.send(:bookkeeping_service)).to receive(:track!).once.and_call_original do |*refs|
            expect(refs.count).to eq(expected_count)
          end
          migration.migrate

          ensure_elasticsearch_index!

          expect(migration.completed?).to be(true)
        end
      end

      context 'when all records have the new schema' do
        it 'does not process documents' do
          migration_klass.const_set(:NEW_SCHEMA_VERSION, current_schema_version)

          expect(migration.send(:bookkeeping_service)).not_to receive(:track!)

          migration.migrate

          expect(migration.completed?).to be(true)
        end
      end

      context 'when queue is full' do
        before do
          allow(migration.send(:bookkeeping_service)).to receive(:queue_size)
            .and_return(described_class::QUEUE_THRESHOLD + 1)
        end

        it 'does not process documents' do
          expect(migration.send(:bookkeeping_service)).not_to receive(:track!)

          migration.migrate

          expect(migration.completed?).to be(false)
        end
      end
    end
  end
end
