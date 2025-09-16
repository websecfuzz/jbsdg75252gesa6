# frozen_string_literal: true

module Geo
  class ContainerRepositoryReplicator < Gitlab::Geo::Replicator
    include ::Geo::VerifiableReplicator

    extend ActiveSupport::Concern

    event ::Geo::ReplicatorEvents::EVENT_CREATED
    event ::Geo::ReplicatorEvents::EVENT_DELETED
    event ::Geo::ReplicatorEvents::EVENT_UPDATED

    class << self
      extend ::Gitlab::Utils::Override

      def model
        ::ContainerRepository
      end

      # @return [String] human-readable title.
      def replicable_title
        s_('Geo|Container Repository')
      end

      # @return [String] pluralized human-readable title.
      def replicable_title_plural
        s_('Geo|Container Repositories')
      end

      # ContainerRepository replication is a bit different in a way that it's not enough
      # to check if the feature flag is enabled we also need to check if
      # it's enabled in the config file Gitlab.config.geo.registry_replication.enabled
      #
      # rubocop:disable Style/IfUnlessModifier
      override :replication_enabled?
      def replication_enabled?
        if ::Gitlab::Geo.secondary?
          return super && Geo::ContainerRepositoryRegistry.replication_enabled?
        end

        super
      end
      # rubocop:enable Style/IfUnlessModifier

      def sync_timeout
        ::Geo::ContainerRepositorySyncService::LEASE_TIMEOUT
      end

      def data_type
        'container_repository'
      end

      def data_type_title
        _('Container Repository')
      end

      def data_type_sort_order
        2
      end
    end

    # Called by Gitlab::Geo::Replicator#consume
    def consume_event_updated(**params)
      return unless in_replicables_for_current_secondary?

      sync
    end

    # Called by Gitlab::Geo::Replicator#consume
    def consume_event_created(...)
      consume_event_updated(...)
    end

    # Called by Gitlab::Geo::Replicator#consume
    def consume_event_deleted(**params)
      replicate_destroy(params)
    end

    def sync
      Geo::ContainerRepositorySyncService.new(model_record).execute
    end
    alias_method :resync, :sync # Backwards compatible with old docs, keep at least till 17.6

    override :deleted_params
    def deleted_params
      event_params.merge(path: model_record.path)
    end

    def replicate_destroy(event_data)
      ::Geo::ContainerRepositoryRegistryRemovalService.new(
        model_record_id,
        event_data[:path]
      ).execute
    end

    def enqueue_sync
      Geo::EventWorker.perform_async(
        replicable_name,
        ::Geo::ReplicatorEvents::EVENT_UPDATED,
        event_params
      )
    end

    # Schedules a verification job after a model record is created/updated
    #
    # Called by Gitlab::Geo::Replicator#geo_handle_after_(create|update)
    def after_verifiable_update
      verify_async if should_primary_verify_after_save?
    end

    # Returns a checksum of the tag list
    #
    # @return [String] SHA256 hash of the repository tag list
    override :calculate_checksum
    def calculate_checksum
      model_record.tag_list_digest
    end

    override :checksummable?
    def checksummable?
      true
    end

    override :immutable?
    def immutable?
      false
    end
  end
end
