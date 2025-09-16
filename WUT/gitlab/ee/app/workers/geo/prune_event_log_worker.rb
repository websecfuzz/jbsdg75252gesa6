# frozen_string_literal: true

module Geo
  class PruneEventLogWorker # rubocop:disable Scalability/IdempotentWorker
    include ApplicationWorker

    data_consistency :always

    # rubocop:disable Scalability/CronWorkerContext
    # This worker does not perform work scoped to a context
    include CronjobQueue
    # rubocop:enable Scalability/CronWorkerContext
    include ::Gitlab::Geo::LogHelpers

    feature_category :geo_replication

    def perform
      return if Gitlab::Database.read_only?
      return if Postgresql::ReplicationSlot.lag_too_great?

      unless ::GeoNode.secondary_nodes.any?
        Geo::PruneEventLogService.new(:all).execute
        return
      end

      unless prune?
        log_info('Some nodes are not healthy, prune geo event log skipped', unhealthy_node_count: unhealthy_nodes.count)
        return
      end

      Geo::PruneEventLogService.new(min_cursor_last_event_id).execute
    end

    def prune?
      unhealthy_nodes.empty?
    end

    def min_cursor_last_event_id
      ::GeoNode.secondary_nodes.min_cursor_last_event_id
    end

    def unhealthy_nodes
      ::GeoNode.secondary_nodes.unhealthy_nodes
    end
  end
end
