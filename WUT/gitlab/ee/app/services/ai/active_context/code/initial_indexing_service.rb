# frozen_string_literal: true

module Ai
  module ActiveContext
    module Code
      class InitialIndexingService
        def self.execute(repository)
          new(repository).execute
        end

        def initialize(repository)
          @repository = repository
        end

        def execute
          repository.code_indexing_in_progress!
          indexed_ids = run_indexer!

          return unless indexed_ids.any?

          repository.embedding_indexing_in_progress!
          enqueue_refs!(indexed_ids)

          set_highest_enqueued_item!(indexed_ids.last)
        rescue StandardError => e
          repository.update!(state: :failed, last_error: e.message)
          raise e
        end

        private

        def run_indexer!
          Indexer.run!(repository)
        end

        def enqueue_refs!(ids)
          ::Ai::ActiveContext::Collections::Code.track_refs!(hashes: ids, routing: repository.project_id)
        end

        def set_highest_enqueued_item!(item)
          repository.update!(
            initial_indexing_last_queued_item: item,
            indexed_at: Time.current
          )
        end

        attr_reader :repository
      end
    end
  end
end
