# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Elastic::MigrationRecord, :elastic_delete_by_query, feature_category: :global_search do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:helper) { Gitlab::Elastic::Helper.default }

  let(:migration) { Class.new }
  let(:record) { described_class.new(version: Time.now.to_i, name: 'ExampleMigration', filename: nil) }

  before do
    allow(record).to receive(:load_migration).and_return(migration)
    allow(Gitlab::Elastic::Helper).to receive(:default).and_return(helper)
  end

  describe '#save!' do
    it 'raises an error if the migrations index is not found' do
      allow(helper).to receive(:index_exists?).with(index_name: 'gitlab-test-migrations').and_return(false)

      expect { record.save!(completed: true) }.to raise_error(/index is not found/)
    end

    it 'sets the migration name' do
      record.save!(completed: false)

      expect(record.load_from_index.dig('_source', 'name')).to eq(record.name)
    end

    it 'sets the started_at' do
      record.save!(completed: false)

      expect(record.load_from_index.dig('_source', 'started_at')).not_to be_nil
    end

    it 'does not update started_at on subsequent saves' do
      record.save!(completed: false)

      real_started_at = record.load_from_index.dig('_source', 'started_at')

      record.save!(completed: false)

      expect(record.load_from_index.dig('_source', 'started_at')).to eq(real_started_at)
    end

    it 'sets completed_at when completed' do
      record.save!(completed: true)

      expect(record.load_from_index.dig('_source', 'completed_at')).not_to be_nil
    end

    it 'does not set completed_at when not completed' do
      record.save!(completed: false)

      expect(record.load_from_index.dig('_source', 'completed_at')).to be_nil
    end
  end

  describe '#load_from_index' do
    it 'does not raise an exception when connection refused' do
      allow(helper.client).to receive(:get).and_raise(Faraday::ConnectionFailed)

      expect(record.load_from_index).to be_nil
    end

    it 'does not raise an exception when record does not exist' do
      allow(helper.client).to receive(:get).and_raise(Elasticsearch::Transport::Transport::Errors::NotFound)

      expect(record.load_from_index).to be_nil
    end
  end

  describe '#halt' do
    it 'sets state for halted and halted_indexing_unpaused' do
      record.halt

      expect(record.load_from_index.dig('_source', 'state', 'halted')).to be_truthy
      expect(record.load_from_index.dig('_source', 'state', 'halted_indexing_unpaused')).to be_falsey
    end

    it 'sets state with additional options if passed' do
      record.halt(hello: 'world', good: 'bye')

      expect(record.load_from_index.dig('_source', 'state', 'hello')).to eq('world')
      expect(record.load_from_index.dig('_source', 'state', 'good')).to eq('bye')
    end
  end

  describe '#fail' do
    it 'calls halt with failed: true' do
      expect(record).to receive(:halt).with({ failed: true, foo: :bar })

      record.fail({ foo: :bar })
    end
  end

  describe '#started?' do
    it 'changes on first save to the index', quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/438942' do
      expect { record.save!(completed: true) }.to change { record.started? }.from(false).to(true)
    end
  end

  describe '.load_versions' do
    let(:completed_versions) { 1.upto(5).map { |i| described_class.new(version: i, name: i, filename: nil) } }
    let(:in_progress_migration) { described_class.new(version: 10, name: 10, filename: nil) }

    before do
      helper.delete_migrations_index
      helper.create_migrations_index
      completed_versions.each { |migration| migration.save!(completed: true) }
      in_progress_migration.save!(completed: false)

      helper.refresh_index(index_name: helper.migrations_index_name)
    end

    it 'loads all records' do
      expect(described_class.load_versions(completed: true)).to match_array(completed_versions.map(&:version))
      expect(described_class.load_versions(completed: false)).to contain_exactly(in_progress_migration.version)
    end

    it 'raises an exception if no index present' do
      allow(Gitlab::Elastic::Helper.default.client)
        .to receive(:search).and_raise(Elasticsearch::Transport::Transport::Errors::NotFound)

      expect do
        described_class.load_versions(completed: true)
      end.to raise_exception(Elasticsearch::Transport::Transport::Errors::NotFound)
      expect do
        described_class.load_versions(completed: false)
      end.to raise_exception(Elasticsearch::Transport::Transport::Errors::NotFound)
    end

    it 'raises an exception when exception is raised' do
      allow(Gitlab::Elastic::Helper.default.client).to receive(:search).and_raise(Faraday::ConnectionFailed)

      expect { described_class.load_versions(completed: true) }.to raise_exception(StandardError)
      expect { described_class.load_versions(completed: false) }.to raise_exception(StandardError)
    end

    it 'has a size constant bigger than the number of migrations' do
      # if this spec fails, bump the constant's value:
      # https://gitlab.com/gitlab-org/gitlab/-/blob/master/ee/app/models/elastic/migration_record.rb#L7

      elastic_migration_path = 'ee/elastic/migrate/*.rb'
      number_of_migrations = Dir[Rails.root.join(elastic_migration_path)].length
      expect(described_class::ELASTICSEARCH_SIZE).to be > number_of_migrations
    end
  end

  describe '#current_migration' do
    before do
      allow(Elastic::DataMigrationService).to receive(:migrations).and_return([record])
      allow(described_class).to receive(:completed_versions).and_return(completed_migrations.map(&:version))
    end

    context 'when there is an unexecuted migration' do
      let(:completed_migrations) { [] }

      it 'returns the correct migration' do
        expect(described_class.current_migration).to eq record
      end
    end

    context 'when there are no uncompleted migrations' do
      let(:completed_migrations) { [record] }

      it 'returns nil' do
        expect(described_class.current_migration).to be_nil
      end
    end
  end

  describe '#running?' do
    before do
      allow(record).to receive_messages(halted?: halted, started?: started, completed?: completed)
    end

    where(:started, :halted, :completed, :expected) do
      false | false | false | false
      true  | false | false | true
      true  | true  | false | false
      true  | true  | true  | false
      true  | false | true  | false
    end

    with_them do
      it 'returns the expected result' do
        expect(record.running?).to eq(expected)
      end
    end
  end

  describe '#stopped?' do
    before do
      allow(record).to receive_messages(halted?: halted, completed?: completed)
    end

    where(:halted, :completed, :expected) do
      false | false | false
      false | true  | true
      true  | false | true
      true  | true  | true
    end

    with_them do
      it 'returns the expected result' do
        expect(record.stopped?).to eq(expected)
      end
    end
  end

  describe '#skip?' do
    context 'when the migration is not skippable' do
      before do
        allow(record).to receive(:skippable?).and_return(false)
      end

      it 'returns false' do
        expect(record.skip?).to be_falsey
      end
    end

    context 'when the migration is skippable' do
      before do
        allow(record).to receive_messages(skippable?: true, obsolete?: obsolete, skip_migration?: skip_migration)
      end

      where(:obsolete, :skip_migration, :expected) do
        false | false | false
        false | true  | true
        true  | false | true
        true  | true  | true
      end

      with_them do
        it 'returns the expected result' do
          expect(record.skip?).to eq(expected)
        end
      end
    end
  end

  describe '#completed_at', :freeze_time do
    subject(:completed_at) { record.completed_at }

    context 'when completed_at is stored in the indexed document' do
      before do
        allow(record).to receive(:load_from_index).and_return({ '_source' => { 'completed_at' => Time.now.utc.to_s } })
      end

      it { is_expected.to eq(Time.now.utc) }
    end

    context 'when completed_at is missing from the indexed document' do
      before do
        allow(record).to receive(:load_from_index).and_return({ '_source' => {} })
      end

      it { is_expected.to be_nil }
    end

    context 'when document is missing from index' do
      before do
        allow(record).to receive(:load_from_index).and_return(nil)
      end

      it { is_expected.to be_nil }
    end
  end

  describe '#started_at', :freeze_time do
    subject(:started_at) { record.started_at }

    context 'when started_at is stored in the indexed document' do
      before do
        allow(record).to receive(:load_from_index).and_return({ '_source' => { 'started_at' => Time.now.utc.to_s } })
      end

      it { is_expected.to eq(Time.now.utc) }
    end

    context 'when started_at is missing from the indexed document' do
      before do
        allow(record).to receive(:load_from_index).and_return({ '_source' => {} })
      end

      it { is_expected.to be_nil }
    end

    context 'when document is missing from index' do
      before do
        allow(record).to receive(:load_from_index).and_return(nil)
      end

      it { is_expected.to be_nil }
    end
  end

  describe '#load_completed_from_index' do
    subject(:load_completed_from_index) { record.load_completed_from_index }

    context 'when completed is missing from the indexed document' do
      before do
        allow(record).to receive(:load_from_index).and_return({ '_source' => {} })
      end

      it { is_expected.to be_nil }
    end

    context 'when completed exists in the indexed document' do
      before do
        allow(record).to receive_messages(load_from_index: { '_source' => { 'completed' => true } }, completed?: false)
      end

      it { is_expected.to be(true) }
    end
  end

  describe '#save_state!' do
    it 'only modifies the state field' do
      record.save!(completed: false)

      original_source = record.load_from_index['_source']

      record.save_state!({ projects: [1], remaining_documents: 500 })

      source = record.load_from_index['_source']
      expected_state = original_source['state'].merge({ 'projects' => [1], 'remaining_documents' => 500 })

      expect(source['state']).to eq(expected_state)

      source.delete('state')
      source.each_key do |key|
        expect(source[key]).to eq(original_source[key])
      end
    end

    it 'only overwrites the state fields provided to the method' do
      record.save_state!({ remaining_documents: 5_000, halted: false })

      original_source = record.load_from_index['_source']

      record.save_state!({ projects: [1], remaining_documents: 100 })

      source = record.load_from_index['_source']
      expected_state = { 'halted' => false, 'projects' => [1], 'remaining_documents' => 100 }

      expect(source['state']).to eq(expected_state)

      source.delete('state')
      source.each_key do |key|
        expect(source[key]).to eq(original_source[key])
      end
    end
  end

  describe '#to_h' do
    it 'returns a hash with completed, name, state, and timestamps', :freeze_time do
      record.save!(completed: false)
      original_source = record.load_from_index['_source']
      expected_hash = original_source.merge('completed' => true, 'completed_at' => Time.now.utc).with_indifferent_access

      result = record.to_h(completed: true).stringify_keys
      expect(result).to eq(expected_hash)
    end

    [true, false].each do |value|
      context "when halted is #{value}" do
        it 'sets halted in the state' do
          expect(record.to_h(completed: true, halted: value)[:state][:halted]).to be(value)
        end
      end
    end
  end
end
