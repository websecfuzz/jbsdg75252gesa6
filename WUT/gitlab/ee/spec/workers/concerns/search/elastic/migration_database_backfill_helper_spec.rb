# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::MigrationDatabaseBackfillHelper, :elastic, feature_category: :global_search do
  context 'when methods are not implemented' do
    let(:migration_class) do
      Class.new do
        include ::Search::Elastic::MigrationDatabaseBackfillHelper
      end
    end

    subject(:migration) { migration_class.new }

    describe '#respect_limited_indexing?' do
      it 'raises a NotImplementedError' do
        expect { migration.respect_limited_indexing? }.to raise_error(NotImplementedError)
      end
    end

    describe '#item_to_preload' do
      it 'raises a NotImplementedError' do
        expect { migration.item_to_preload }.to raise_error(NotImplementedError)
      end
    end
  end

  context 'when respect_limited_indexing? is false' do
    let(:migration_class) do
      Class.new(Elastic::Migration) do
        include ::Search::Elastic::MigrationDatabaseBackfillHelper

        batch_size 10_000
        batched!
        throttle_delay 1.minute
        retry_on_failure

        def item_to_preload
          :project
        end

        def respect_limited_indexing?
          false
        end
      end
    end

    let(:version) { 30231204134928 }
    let(:objects) { create_list(:issue, 3) }

    subject(:migration) { migration_class.new(version) }

    describe '#migrate' do
      before do
        stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
        set_elasticsearch_migration_to(version, including: false)
        stub_const("#{described_class}::DOCUMENT_TYPE", Issue)

        # ensure objects are indexed
        objects

        migration_record = Elastic::MigrationRecord.new(version: version, name: 'SomeName', filename: 'some_file')
        allow(Elastic::DataMigrationService).to receive(:[]).and_return(migration_record)
        ensure_elasticsearch_index!
        migration.set_migration_state(current_id: 0)
      end

      it 'respects the limiting setting' do
        allow(::Gitlab::CurrentSettings).to receive(:elasticsearch_indexes_project?).with(anything).and_return(false)
        expected_count = objects.size
        expect(::Elastic::ProcessInitialBookkeepingService).to receive(:track!).once.and_call_original do |*refs|
          expect(refs.count).to eq(expected_count)
        end
        migration.migrate

        ensure_elasticsearch_index!

        expect(migration.completed?).to be_truthy
      end

      context 'when queue is full' do
        before do
          allow(migration.bookkeeping_service).to receive(:queue_size).and_return(described_class::QUEUE_THRESHOLD + 1)
        end

        it 'does not process documents' do
          expect(::Elastic::ProcessInitialBookkeepingService).not_to receive(:track!)

          migration.migrate

          expect(migration.completed?).to be_falsey
        end
      end
    end
  end

  describe '#bookkeeping_service' do
    let(:migration_class) do
      Class.new do
        include ::Search::Elastic::MigrationDatabaseBackfillHelper
      end
    end

    subject(:migration) { migration_class.new }

    it 'returns the ProcessInitialBookkeepingService by default' do
      expect(migration.bookkeeping_service).to eq(::Elastic::ProcessInitialBookkeepingService)
    end
  end
end
