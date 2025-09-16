# frozen_string_literal: true

module Search
  module Zoekt
    class IndexingTaskWorker
      include ApplicationWorker
      include Search::Worker
      prepend ::Geo::SkipSecondary

      data_consistency :delayed
      idempotent!
      urgency :low

      concurrency_limit -> { 2_000 }

      defer_on_database_health_signal :gitlab_main, [:zoekt_nodes, :zoekt_indices, :zoekt_tasks], 10.minutes

      def perform(project_id, task_type, options = {})
        return false unless ::Search::Zoekt.licensed_and_indexing_enabled?

        options = options.with_indifferent_access
        keyword_args = {
          node_id: options[:node_id], delay: options[:delay],
          root_namespace_id: options[:root_namespace_id]
        }.compact
        IndexingTaskService.execute(project_id, task_type, **keyword_args)
      end
    end
  end
end
