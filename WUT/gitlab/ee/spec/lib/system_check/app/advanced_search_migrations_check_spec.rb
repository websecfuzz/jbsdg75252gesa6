# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SystemCheck::App::AdvancedSearchMigrationsCheck, feature_category: :global_search do
  subject(:instance) { described_class.new }

  let(:version) { '20220101800000' }
  let(:file) { 'test_migrate.rb' }
  let(:migration_files) { ["ee/elastic/migrate/#{version}_#{file}"] }
  let(:migration) do
    instance_double(
      Elastic::MigrationRecord, version: version, name_for_key: 'test_migrate', filename: file, skip?: false
    )
  end

  before do
    allow(Elastic::MigrationRecord).to receive(:new).and_return(migration)
  end

  describe '.skip?' do
    context 'with elasticsearch disabled' do
      it 'returns true' do
        stub_ee_application_setting(elasticsearch_indexing?: false)
        expect(instance).to be_skip
      end
    end

    context 'with elasticsearch enabled' do
      it 'returns false' do
        stub_ee_application_setting(elasticsearch_indexing?: true)
        expect(instance).not_to be_skip
      end
    end
  end

  describe '.check?' do
    context 'with pending migrations' do
      it 'returns false' do
        allow(Elastic::DataMigrationService).to receive(:pending_migrations?).and_return(true)
        expect(instance).not_to be_check
      end
    end

    context 'without pending migrations' do
      it 'returns true' do
        allow(Elastic::DataMigrationService).to receive(:pending_migrations?).and_return(false)
        expect(instance).to be_check
      end
    end
  end

  describe '.show_error' do
    it 'returns the elasticsearch.md page' do
      expect(instance).to receive(:for_more_information)
                           .with('https://docs.gitlab.com/ee/integration/advanced_search/elasticsearch.html#all-migrations-must-be-finished-before-doing-a-major-upgrade')
      expect(instance).to receive(:try_fixing_it).with(
        'Wait for all advanced search migrations to complete.',
        'To list pending migrations, run `sudo gitlab-rake gitlab:elastic:list_pending_migrations`'
      )
      instance.show_error
    end
  end

  describe '#fail_info' do
    subject { described_class.fail_info }

    context 'when pending migration count is 1' do
      before do
        allow(described_class).to receive(:pending_migrations_count).and_return 1
      end

      it { is_expected.to eq 'no (You have 1 pending migration.)' }
    end

    context 'when pending migration count is greater than 1' do
      before do
        allow(described_class).to receive(:pending_migrations_count).and_return 5
      end

      it { is_expected.to eq 'no (You have 5 pending migrations.)' }
    end
  end

  describe '#pending_migrations_count' do
    subject { described_class.pending_migrations_count }

    context 'with pending migrations' do
      before do
        allow(Elastic::DataMigrationService).to receive(:pending_migrations).and_return([migration])
      end

      it { is_expected.to eq 1 }
    end

    context 'without pending migrations' do
      before do
        allow(Elastic::DataMigrationService).to receive(:pending_migrations).and_return([])
      end

      it { is_expected.to eq 0 }
    end

    context 'when pending_migrations returns a nil value' do
      before do
        allow(Elastic::DataMigrationService).to receive(:pending_migrations).and_return(nil)
      end

      it { is_expected.to eq 0 }
    end
  end
end
