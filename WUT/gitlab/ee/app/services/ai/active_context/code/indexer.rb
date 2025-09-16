# frozen_string_literal: true

module Ai
  module ActiveContext
    module Code
      class Indexer
        include Gitlab::Utils::StrongMemoize

        TIMEOUT = '30m'
        Error = Class.new(StandardError)

        def self.run!(repository)
          new(repository).run
        end

        attr_reader :repository, :project

        def initialize(repository)
          @repository = repository
          @project = repository.project
        end

        def run
          raise Error, 'Adapter not set' unless adapter
          raise Error, 'Commit not found' unless to_commit

          # Response from indexer is currently processed all at once but should be handled as it is streamed in batches
          # https://gitlab.com/gitlab-org/gitlab/-/issues/551837
          output, status = Gitlab::Popen.popen(command, nil, environment_variables)

          raise Error, "Indexer failed: #{output}" unless status == 0

          repository.update!(last_commit: to_commit.id)

          IndexerResponseModifier.extract_ids(output)
        end

        private

        def command
          [
            Gitlab.config.elasticsearch.indexer_path,
            '-adapter', adapter.name,
            '-connection', ::Gitlab::Json.generate(connection),
            '-options', ::Gitlab::Json.generate(options)
          ]
        end

        def environment_variables
          { 'GITLAB_INDEXER_MODE' => 'chunk' }
        end

        def connection
          adapter.connection.options
        end

        def options
          {
            from_sha: repository.last_commit,
            to_sha: to_commit.id,
            project_id: project.id,
            partition_name: collection_class.partition_name,
            partition_number: collection_class.partition_number(project.id),
            gitaly_config: gitaly_config,
            timeout: TIMEOUT
          }
        end

        def gitaly_config
          {
            address: Gitlab::GitalyClient.address(project.repository_storage),
            storage: project.repository_storage,
            relative_path: project.repository.relative_path,
            project_path: project.full_path
          }
        end

        def to_commit
          project.repository.commit
        end

        def collection_class
          ::Ai::ActiveContext::Collections::Code
        end

        def adapter
          ::ActiveContext.adapter
        end
        strong_memoize_attr :adapter
      end
    end
  end
end
