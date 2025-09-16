# frozen_string_literal: true

RSpec.shared_examples 'migration backfills fields' do
  let(:migration) { described_class.new(version) }
  let(:klass) { objects.first.class }
  let(:index_name) { migration.index_name }
  let(:bookkeeping_service) { ::Elastic::ProcessInitialBookkeepingService }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    set_elasticsearch_migration_to(version, including: false)

    # ensure objects are indexed
    objects

    ensure_elasticsearch_index!
  end

  describe 'migration_options' do
    it 'has migration options set', :aggregate_failures do
      expect(migration).to be_batched
      expect(migration.throttle_delay).to eq(expected_throttle_delay)
      expect(migration.batch_size).to eq(expected_batch_size)
    end
  end

  describe '.migrate' do
    subject { migration.migrate }

    context 'when migration is already completed' do
      it 'does not modify data' do
        expect(bookkeeping_service).not_to receive(:track!)

        subject
      end
    end

    describe 'migration process' do
      before do
        remove_field_from_objects(objects)
      end

      it 'updates all documents' do
        # track calls are batched in groups of 100
        expect(bookkeeping_service).to receive(:track!)
          .once.and_call_original do |*tracked_refs|
          expect(tracked_refs.count).to eq(objects.size)
        end

        subject

        ensure_elasticsearch_index!

        expect(migration.completed?).to be_truthy
      end

      it 'only updates documents missing a field', :aggregate_failures do
        object = objects.first
        add_field_for_objects(objects[1..])

        expect(bookkeeping_service).to receive(:track!)
          .once.and_call_original do |*tracked_refs|
          expect(tracked_refs.count).to eq(1)
          expect(::Search::Elastic::Reference.deserialize(tracked_refs.first).identifier).to eq(object.id)
        end

        subject

        ensure_elasticsearch_index!

        expect(migration.completed?).to be_truthy
      end

      it 'processes in batches', :aggregate_failures do
        allow(migration).to receive_messages(batch_size: 2, update_batch_size: 1)

        # the migration is run two times, so expect at most 4 calls to track!
        expected_track_calls = [objects.size, 4].min

        expect(bookkeeping_service)
          .to receive(:track!).exactly(expected_track_calls).times.and_call_original

        # cannot use subject in spec because it is memoized
        migration.migrate

        ensure_elasticsearch_index!

        migration.migrate

        ensure_elasticsearch_index!

        expect(migration.completed?).to be_truthy
      end
    end
  end

  describe '.completed?' do
    context 'when documents are missing field' do
      before do
        remove_field_from_objects(objects)
      end

      specify { expect(migration).not_to be_completed }
    end

    context 'when no documents are missing field' do
      specify { expect(migration).to be_completed }
    end
  end

  private

  def add_field_for_objects(objects)
    source_script = expected_fields.map do |field_name, _|
      "ctx._source['#{field_name}'] = params.#{field_name};"
    end.join

    script =  {
      source: source_script,
      lang: "painless",
      params: expected_fields
    }

    update_by_query(objects, script)
  end

  def remove_field_from_objects(objects)
    source_script = expected_fields.map do |field_name, _|
      "ctx._source.remove('#{field_name}');"
    end.join

    script = {
      source: source_script
    }

    update_by_query(objects, script)
  end

  def update_by_query(objects, script)
    object_ids = objects.map(&:id)

    client = klass.__elasticsearch__.client
    client.update_by_query({
      index: index_name,
      wait_for_completion: true, # run synchronously
      refresh: true, # make operation visible to search
      body: {
        script: script,
        query: {
          bool: {
            must: [
              {
                terms: {
                  id: object_ids
                }
              }
            ]
          }
        }
      }
    })
  end
end

RSpec.shared_examples 'migration reindex based on schema_version' do
  let_it_be(:client) { Gitlab::Search::Client.new }
  let(:migration) { described_class.new(version) }
  let(:klass) { objects.first.class }
  let(:index_name) { migration.index_name }
  let(:bookkeeping_service) { migration.send(:bookkeeping_service) }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    set_elasticsearch_migration_to(version, including: false)

    # ensure objects are indexed
    bookkeeping_service.track!(*objects)

    ensure_elasticsearch_index!
  end

  it 'index has schema_version in the mapping' do
    mapping = client.indices.get_field_mapping(index: index_name, fields: 'schema_version')
    expect(mapping.values.all? { |m| m['mappings']['schema_version'].present? }).to be true
  end

  describe 'migration_options' do
    it 'has migration options set', :aggregate_failures do
      expect(migration).to be_batched
      expect(migration.throttle_delay).to eq(expected_throttle_delay)
      expect(migration.batch_size).to eq(expected_batch_size)
    end
  end

  describe '.migrate' do
    subject { migration.migrate }

    context 'when migration is already completed' do
      it 'does not modify data' do
        expect(bookkeeping_service).not_to receive(:track!)

        assert_objects_have_new_schema_version(objects)

        subject
      end
    end

    describe 'migration process' do
      before do
        update_by_query(objects, { source: "ctx._source.schema_version=#{described_class::NEW_SCHEMA_VERSION.pred}" })
      end

      context 'when an error is raised' do
        before do
          allow(migration).to receive(:process_batch!).and_raise(StandardError, 'E')
          allow(migration).to receive(:log).and_return(true)
        end

        it 'logs a message' do
          expect(migration).to receive(:log_raise)
            .with('migrate failed', error_class: StandardError, error_message: 'E')
          subject
        end
      end

      context 'when migration does not responds to batch_size' do
        before do
          allow(migration).to receive(:respond_to?).with(:batch_size).and_return nil
        end

        it 'raises NotImplementedError' do
          expect { subject }.to raise_error NotImplementedError
        end
      end

      context 'when all documents needs to be updated' do
        it 'updates all documents' do
          # track calls are batched in groups of 100
          expect(bookkeeping_service).to receive(:track!).once.and_call_original do |*tracked_refs|
            expect(tracked_refs.count).to eq(objects.size)
          end

          subject

          ensure_elasticsearch_index!

          assert_objects_have_new_schema_version(objects)
          expect(migration.completed?).to be_truthy
        end
      end

      context 'when some documents needs to be updated' do
        let(:sample_object) { objects.last }

        before do
          # Set the new schema_version for all the objects except sample_object
          schema_ver = described_class::NEW_SCHEMA_VERSION
          update_by_query(objects.excluding(sample_object), { source: "ctx._source.schema_version=#{schema_ver}" })
        end

        it 'only updates documents whose schema_version is old', :aggregate_failures do
          expect(bookkeeping_service).to receive(:track!)
            .once.and_call_original do |*tracked_refs|
            expect(tracked_refs.count).to eq(1)
            ref = ::Search::Elastic::Reference.deserialize(tracked_refs.first)
            expect(ref.identifier).to eq(sample_object.id)
            expect(ref.routing).to eq(sample_object.es_parent)
          end

          subject

          ensure_elasticsearch_index!

          assert_objects_have_new_schema_version(objects)
          expect(migration.completed?).to be_truthy
        end
      end

      it 'processes in batches', :aggregate_failures do
        allow(migration).to receive_messages(batch_size: 2, update_batch_size: 1)

        # the migration is run two times, so expect at most 4 calls to track!
        expected_track_calls = [objects.size, 4].min

        expect(bookkeeping_service).to receive(:track!).exactly(expected_track_calls).times.and_call_original

        # cannot use subject in spec because it is memoized
        migration.migrate

        ensure_elasticsearch_index!

        migration.migrate

        ensure_elasticsearch_index!

        assert_objects_have_new_schema_version(objects)

        # if more than 4 objects exist, running 2 batches of 2 records won't finish the migration
        should_be_completed = objects.size <= 4
        expect(migration.completed?).to eq(should_be_completed)
      end
    end

    context 'when documents have empty schema_version' do
      before do
        update_by_query(objects.take(1), { source: "ctx._source.remove('schema_version');" })
      end

      it 'sets the new schema_version for all the documents' do
        expect(client.count(body: { query: { bool: { must_not: { exists: { field: 'schema_version' } } } } },
          index: index_name)['count']).to be > 0
        subject
        ensure_elasticsearch_index!
        expect(migration).to be_completed

        assert_objects_have_new_schema_version(objects)
      end
    end
  end

  describe '.completed?' do
    let(:schema_ver) { described_class::NEW_SCHEMA_VERSION }

    context 'when documents have still old schema_version' do
      before do
        update_by_query(objects, { source: "ctx._source.schema_version=#{schema_ver.pred}" })
      end

      it { expect(migration).not_to be_completed }

      it 'all objects return the new schema_version' do
        assert_objects_have_new_schema_version(objects)
      end
    end

    context 'when no documents have old schema_version' do
      it { expect(migration).to be_completed }

      it 'all objects return the new schema_version' do
        assert_objects_have_new_schema_version(objects)
      end
    end
  end

  private

  def update_by_query(objects, script)
    object_ids = objects.map(&:id)

    client.update_by_query({
      index: index_name,
      wait_for_completion: true, # run synchronously
      refresh: true, # make operation visible to search
      body: {
        script: script,
        query: {
          bool: {
            must: [
              {
                terms: {
                  id: object_ids
                }
              }
            ]
          }
        }
      }
    })
  end

  def assert_objects_have_new_schema_version(objects, schema_version = described_class::NEW_SCHEMA_VERSION)
    result = objects.all? do |o|
      ref = ::Search::Elastic::Reference.serialize(o)
      Search::Elastic::Reference.deserialize(ref).as_indexed_json['schema_version'] >= schema_version
    end
    expect(result).to be true
  end
end

RSpec.shared_examples 'migration adds mapping' do
  let(:migration) { described_class.new(version) }
  let(:helper) { Gitlab::Elastic::Helper.new }

  before do
    allow(migration).to receive(:helper).and_return(helper)
  end

  describe '.migrate' do
    subject { migration.migrate }

    context 'when migration is already completed' do
      it 'does not modify data' do
        expect(helper).not_to receive(:update_mapping)

        subject
      end
    end

    describe 'migration process' do
      before do
        allow(helper).to receive(:get_mapping).and_return({})
      end

      it 'updates the issues index mappings' do
        expect(helper).to receive(:update_mapping)

        subject
      end
    end
  end

  describe '.completed?' do
    context 'when mapping has been updated' do
      specify { expect(migration).to be_completed }
    end

    context 'when mapping has not been updated' do
      before do
        allow(helper).to receive(:get_mapping).and_return({})
      end

      specify { expect(migration).not_to be_completed }
    end
  end
end

RSpec.shared_examples 'migration creates a new index' do |version, klass|
  let(:helper) { Gitlab::Elastic::Helper.new }

  before do
    allow(subject).to receive(:helper).and_return(helper)
  end

  subject { described_class.new(version) }

  describe '#migrate' do
    it 'logs a message and creates a standalone index' do
      expect(subject).to receive(:log).with(/Creating standalone .* index/)
      expect(helper).to receive(:create_standalone_indices).with(target_classes: [klass]).and_return(true).once

      subject.migrate
    end

    describe 'reindexing_cleanup!' do
      context 'when the index already exists' do
        before do
          allow(helper).to receive_messages(index_exists?: true, create_standalone_indices: true)
        end

        it 'deletes the index' do
          expect(helper).to receive(:delete_index).once

          subject.migrate
        end
      end
    end

    context 'when an error is raised' do
      let(:error) { 'oops' }

      before do
        allow(helper).to receive(:create_standalone_indices).and_raise(StandardError, error)
        allow(subject).to receive(:log).and_return(true)
      end

      it 'logs a message and raises an error' do
        expect(subject).to receive(:log).with(/Failed to create index/, error: error)

        expect { subject.migrate }.to raise_error(StandardError, error)
      end
    end
  end

  describe '#completed?' do
    [true, false].each do |matcher|
      it 'returns true if the index exists' do
        allow(helper).to receive(:create_standalone_indices).and_return(true)
        allow(helper).to receive(:index_exists?).with(index_name: /gitlab-test-/).and_return(matcher)

        expect(subject.completed?).to eq(matcher)
      end
    end
  end
end

RSpec.shared_examples 'a deprecated Advanced Search migration' do |version|
  subject { described_class.new(version) }

  describe '#migrate' do
    it 'logs a message and halts the migration' do
      expect(subject).to receive(:log).with(/has been deleted in the last major version upgrade/)
      expect(subject).to receive(:fail_migration_halt_error!).and_return(true)

      subject.migrate
    end
  end

  describe '#completed?' do
    it 'returns false' do
      expect(subject.completed?).to be false
    end
  end

  describe '#obsolete?' do
    it 'returns true' do
      expect(subject.obsolete?).to be true
    end
  end
end

RSpec.shared_examples 'migration reindexes all data' do
  let(:migration) { described_class.new(version) }
  let(:klass) { objects.first.class }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    set_elasticsearch_migration_to(version, including: false)

    # ensure objects are indexed
    objects

    ensure_elasticsearch_index!
  end

  describe 'QueryRecorder to check N+1' do
    let(:factory_name) do
      if defined?(factory_to_create_objects)
        factory_to_create_objects
      else
        klass.name.downcase.to_sym
      end
    end

    before do
      klass.delete_all
    end

    it 'avoids N+1 queries', :use_sql_query_cache do
      create_list(factory_name, 1)
      ensure_elasticsearch_index!

      control = ActiveRecord::QueryRecorder.new(skip_cached: false) { migration.migrate }

      klass.delete_all
      migration.set_migration_state(migration.migration_state.keys.index_with { nil })

      create_list(factory_name, 3)
      ensure_elasticsearch_index!

      expect { migration.migrate }.to issue_same_number_of_queries_as(control)
    end
  end

  describe 'migration_options' do
    it 'has migration options set', :aggregate_failures do
      expect(migration).to be_batched
      expect(migration.throttle_delay).to eq(expected_throttle_delay)
      expect(migration.batch_size).to eq(expected_batch_size)
    end
  end

  describe '.migrate' do
    subject { migration.migrate }

    context 'when migration is already completed' do
      before do
        migration.set_migration_state(current_id: objects.map(&:id).max)
      end

      it 'does not modify data' do
        expect(::Elastic::ProcessInitialBookkeepingService).not_to receive(:track!)

        subject
      end
    end

    describe 'migration process' do
      before do
        stub_ee_application_setting(elasticsearch_limit_indexing?: true)
        migration.set_migration_state(current_id: 0)
      end

      it 'respects the limiting setting' do
        if migration.respect_limited_indexing?

          allow(migration.document_type).to receive(:maintaining_elasticsearch?).and_return(false)
          expected_count = 0
        else
          expected_count = objects.size
        end

        expect(::Elastic::ProcessInitialBookkeepingService).to receive(:track!)
          .once.and_call_original do |*tracked_refs|
          expect(tracked_refs.count).to eq(expected_count)
        end
        subject

        ensure_elasticsearch_index!

        expect(migration.completed?).to be_truthy
      end

      it 'updates all documents' do
        expect(::Elastic::ProcessInitialBookkeepingService).to receive(:track!)
          .once.and_call_original do |*tracked_refs|
          expect(tracked_refs.count).to eq(objects.size)
        end

        subject

        ensure_elasticsearch_index!

        expect(migration.completed?).to be_truthy
      end

      it 'processes in batches', :aggregate_failures do
        allow(migration).to receive_messages(batch_size: 1, limit_per_iteration: 1)

        expect(::Elastic::ProcessInitialBookkeepingService).to receive(:track!)
          .exactly(objects.size).times.and_call_original

        # cannot use subject in spec because it is memoized
        migration.migrate

        ensure_elasticsearch_index!

        migration.migrate

        ensure_elasticsearch_index!

        migration.migrate

        ensure_elasticsearch_index!

        expect(migration.completed?).to be_truthy
      end
    end
  end

  describe '.completed?' do
    context 'when all data has been backfilled' do
      before do
        migration.set_migration_state(current_id: objects.map(&:id).max)
      end

      specify { expect(migration).to be_completed }
    end

    context 'when some data is left to be backfilled' do
      before do
        migration.set_migration_state(current_id: 0)
      end

      specify { expect(migration).not_to be_completed }
    end
  end
end

RSpec.shared_examples 'migration deletes documents based on schema version' do
  let(:migration) { described_class.new(version) }
  let(:klass) { objects.first.class }
  let(:helper) { Gitlab::Elastic::Helper.new }
  let(:client) { ::Gitlab::Search::Client.new }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    set_elasticsearch_migration_to(version, including: false)
    allow(migration).to receive_messages(helper: helper, client: client)

    # ensure objects are indexed
    objects

    ensure_elasticsearch_index!
  end

  after do
    update_by_query(objects, { source: "ctx._source.schema_version=#{migration.schema_version}" })
  end

  describe 'migration_options' do
    it 'has migration options set', :aggregate_failures do
      expect(migration).to be_batched
      expect(migration.throttle_delay).to eq(expected_throttle_delay)
      expect(migration.batch_size).to eq(expected_batch_size)
    end
  end

  describe '.migrate', :elastic, :sidekiq_inline do
    subject { migration.migrate }

    context 'when migration fails' do
      context 'and es responds with errors' do
        before do
          allow(client).to receive(:delete_by_query).and_return('task' => 'task_1')
        end

        context 'when a task throws an error' do
          before do
            update_by_query(objects, { source: "ctx._source.schema_version=#{migration.schema_version.pred}" })
            migration.migrate
            allow(helper).to receive(:task_status).and_return('error' => ['failed'])
          end

          it 'resets task_id' do
            expect { migration.migrate }.to raise_error(/Failed to delete/)
            expect(migration.migration_state).to match(task_id: nil, documents_remaining: anything)
          end
        end

        context 'when delete_by_query fails' do
          before do
            update_by_query(objects, { source: "ctx._source.schema_version=#{migration.schema_version.pred}" })
            allow(client).to receive(:delete_by_query).and_return('failures' => 'failed')
          end

          it 'resets task_id' do
            expect { migration.migrate }.to raise_error(/Failed to delete/)
            expect(migration.migration_state).to match(task_id: nil, documents_remaining: anything)
          end
        end
      end
    end

    context 'when migration is already completed' do
      it 'does not modify data' do
        expect(::Elastic::ProcessInitialBookkeepingService).not_to receive(:track!)
        schema_version = migration.schema_version
        expect(objects.all? { |o| o.__elasticsearch__.as_indexed_json['schema_version'] >= schema_version }).to be true

        subject
      end
    end

    describe 'migration process' do
      before do
        update_by_query(objects, { source: "ctx._source.schema_version=#{migration.schema_version.pred}" })
      end

      context 'when task in progress' do
        before do
          allow(migration).to receive_messages(completed?: false, client: client)
          allow(helper).to receive(:task_status).and_return('completed' => false)
          migration.set_migration_state(task_id: 'task_1')
        end

        it 'does nothing if task is not completed' do
          migration.migrate
          expect(client).not_to receive(:delete_by_query)
          migration.set_migration_state(task_id: nil)
        end
      end

      context 'when documents are still present in the index' do
        it 'removes documents from the index' do
          expect(migration.completed?).to be_falsey
          migration.migrate
          expect(migration.migration_state).to match(documents_remaining: anything, task_id: anything)
          # the migration might not complete after the initial task is created
          # so make sure it actually completes
          10.times do
            migration.migrate
            break if migration.completed?

            sleep 0.02
          end

          migration.migrate # To set a pristine state
          expect(migration.completed?).to be_truthy
        end

        context 'and task in progress' do
          it 'does nothing if task is not completed' do
            allow(migration).to receive(:completed?).and_return(false)
            allow(helper).to receive(:task_status).and_return('completed' => false)
            migration.set_migration_state(task_id: 'task_1')
            migration.migrate
            expect(client).not_to receive(:delete_by_query)
          end
        end
      end
    end
  end

  describe '.completed?' do
    context 'when all data has been deleted' do
      before do
        update_by_query(objects, { source: "ctx._source.schema_version=#{migration.schema_version}" })
      end

      specify { expect(migration).to be_completed }
    end

    context 'when some data is left to be deleted' do
      before do
        update_by_query(objects, { source: "ctx._source.schema_version=#{migration.schema_version.pred}" })
      end

      specify { expect(migration).not_to be_completed }
    end
  end

  private

  def update_by_query(objects, script)
    object_ids = objects.map(&:id)
    client.update_by_query({
      index: migration.index_name,
      wait_for_completion: true, # run synchronously
      refresh: true, # make operation visible to search
      body: {
        script: script,
        query: {
          bool: {
            must: [
              {
                terms: {
                  id: object_ids
                }
              }
            ]
          }
        }
      }
    })
  end
end

RSpec.shared_examples 'migration removes field' do
  let_it_be(:client) { ::Gitlab::Search::Client.new }
  let(:migration) { described_class.new(version) }
  let(:klass) { objects.first.class }
  let(:index_name) { migration.index_name }
  let(:value) { 1 }
  let(:mapping) { { type: type } }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    objects
    ensure_elasticsearch_index!
  end

  describe 'migration options' do
    it 'has migration options set', :aggregate_failures do
      expect(migration).to be_batched
      expect(migration.throttle_delay).to eq(expected_throttle_delay)
    end
  end

  describe '#completed?' do
    context 'when field is present in the mapping' do
      before do
        add_field_in_mapping!(mapping)
      end

      context 'when some documents have the value for field set' do
        before do
          add_field_value_to_documents!(3, value)
        end

        it 'returns false' do
          expect(migration.completed?).to be false
        end
      end

      context 'when no documents have the value for field set' do
        it 'returns true' do
          expect(migration.completed?).to be true
        end
      end
    end

    context 'when field is not present in the mapping' do
      it 'returns true' do
        expect(migration.completed?).to be true
      end
    end
  end

  describe '#migrate' do
    let(:original_target_doc_count) { 5 }
    let(:batch_size) { 2 }

    before do
      add_field_in_mapping!(mapping)
      add_field_value_to_documents!(original_target_doc_count, value)
      allow(migration).to receive(:batch_size).and_return(batch_size)
    end

    it 'completes the migration in batches' do
      expect(documents_count_with_field).to eq original_target_doc_count
      expect(migration.completed?).to be false
      migration.migrate
      expect(migration.completed?).to be false
      expect(documents_count_with_field).to eq original_target_doc_count - batch_size
      10.times do
        break if migration.completed?

        migration.migrate
        sleep 0.01
      end
      expect(migration.completed?).to be true
      expect(documents_count_with_field).to eq 0
    end
  end

  def add_field_in_mapping!(mapping)
    client.indices.put_mapping(index: index_name,
      body: { properties: { "#{field}": mapping } }
    )
  end

  def add_field_value_to_documents!(count, value)
    client.update_by_query(index: index_name, refresh: true, body: {
      script: { source: "ctx._source.#{field}=#{value}" }, max_docs: count
    })
  end

  def documents_count_with_field
    client.count(index: index_name,
      body: { query: { bool: { must: { exists: { field: field } } } } }
    )['count']
  end
end
