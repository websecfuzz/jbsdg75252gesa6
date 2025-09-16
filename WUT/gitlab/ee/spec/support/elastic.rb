# frozen_string_literal: true

module Elastic
  class TestHelpers
    include ElasticsearchHelpers

    INDEX_PREFIX = 'gitlab-test*'

    def helper
      @helper ||= Gitlab::Elastic::Helper.default
    end

    def indices(include_migration_index: true)
      aliases = helper.client.cat.aliases(name: INDEX_PREFIX, format: 'json')
      indices = if aliases.empty?
                  []
                else
                  names = aliases.pluck('index')
                  helper.client.cat.indices(
                    index: names, expand_wildcards: 'open', format: 'json', pri: true, bytes: 'gb'
                  )
                end.pluck('index')

      indices << helper.migrations_index_name if include_migration_index
      indices
    end

    def setup
      clear_tracking!
      benchmark(:delete_indices!) { delete_indices! }

      benchmark(:create_migrations_index) { helper.create_migrations_index }
      benchmark(:mark_all_as_completed!) { Elastic::DataMigrationService.mark_all_as_completed! }

      name_suffix = Time.now.utc.strftime('%S.%L')
      benchmark(:create_empty_index) do
        helper.create_empty_index(options: { settings: { number_of_replicas: 0 }, name_suffix: name_suffix })
      end
      benchmark(:create_standalone_indices) do
        helper.create_standalone_indices(options: { settings: { number_of_replicas: 0 }, name_suffix: name_suffix })
      end

      refresh_elasticsearch_index!
    end

    def teardown
      delete_indices!
      clear_tracking!
    end

    def clear_tracking!
      Elastic::ProcessInitialBookkeepingService.clear_tracking!
      Elastic::ProcessBookkeepingService.clear_tracking!
    end

    def refresh_elasticsearch_index!
      refresh_index!
    end

    def delete_indices!
      indices.each do |index_name|
        helper.delete_index(index_name: index_name)
      end
    end

    def delete_all_data_from_index!
      helper.client.delete_by_query(
        {
          index: indices(include_migration_index: false),
          body: { query: { match_all: {} } },
          slices: 5,
          conflicts: 'proceed'
        }
      )
    end

    def benchmark(name)
      return yield unless ENV['SEARCH_SPEC_BENCHMARK']

      result = nil
      time = Benchmark.realtime do
        result = yield
      end

      puts({ name: name, elapsed_time: time.round(2) }.to_json)

      result
    end
  end
end

RSpec.configure do |config|
  config.define_derived_metadata do |meta|
    meta[:clean_gitlab_redis_cache] = true if meta[:elastic] || meta[:elastic_delete_by_query] || meta[:elastic_clean]
    meta[:clean_gitlab_redis_cache] = true if meta[:zoekt]
  end

  # If using the :elastic tag is causing issues, use :elastic_clean instead.
  # :elastic is significantly faster than :elastic_clean and should be used
  # wherever possible.
  config.before(:all, :elastic) do
    helper = Elastic::TestHelpers.new
    helper.setup
  end

  config.after(:all, :elastic) do
    helper = Elastic::TestHelpers.new
    helper.teardown
  end

  config.around(:each, :elastic) do |example|
    helper = Elastic::TestHelpers.new
    helper.refresh_elasticsearch_index!

    example.run
  end

  config.around(:each, :elastic_clean) do |example|
    helper = Elastic::TestHelpers.new
    helper.setup

    example.run

    helper.teardown
  end

  config.before(:context, :elastic_delete_by_query) do
    Elastic::TestHelpers.new.setup
  end

  config.after(:context, :elastic_delete_by_query) do
    Elastic::TestHelpers.new.teardown
  end

  config.around(:each, :elastic_delete_by_query) do |example|
    helper = Elastic::TestHelpers.new
    helper.refresh_elasticsearch_index!

    example.run

    helper.delete_all_data_from_index!
  end

  config.include ElasticsearchHelpers, :elastic
  config.include ElasticsearchHelpers, :elastic_clean
  config.include ElasticsearchHelpers, :elastic_delete_by_query
  config.include ElasticsearchHelpers, :elastic_helpers
end
