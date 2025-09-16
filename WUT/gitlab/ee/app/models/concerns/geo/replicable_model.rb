# frozen_string_literal: true

module Geo
  module ReplicableModel
    extend ActiveSupport::Concern
    include Checksummable
    include HasReplicator
    include ::Gitlab::Geo::LogHelpers
    include ::Gitlab::Utils::StrongMemoize

    included do
      # If this hook turns out not to apply to all Models, perhaps we should extract a `ReplicableBlobModel`
      after_create_commit :geo_create_event!
      after_destroy -> do
        replicator.geo_handle_after_destroy if replicator.respond_to?(:geo_handle_after_destroy)
      rescue StandardError => err
        log_error("Geo replicator after_destroy failed", err)
      end

      delegate :geo_handle_after_create, to: :replicator
      delegate :geo_handle_after_destroy, to: :replicator
      delegate :geo_handle_after_update, to: :replicator

      # These scopes are intended to be overridden as needed
      scope :available_replicables, -> { all }

      # On primary, `verifiables` are records that can be checksummed and/or are replicable.
      # On secondary, `verifiables` are records that have already been replicated
      # and (ideally) have been checksummed on the primary
      scope :verifiables, -> do
        node = ::GeoNode.current_node

        replicables =
          available_replicables
            .merge(object_storage_scope(node))

        if ::Gitlab::Geo.org_mover_extend_selective_sync_to_primary_checksumming?
          replicables.merge(selective_sync_scope(node, replicables: replicables))
        else
          replicables
        end
      end

      # When storing verification details in the same table as the model,
      # the scope `available_verifiables` returns only those records
      # that are eligible for verification, i.e. the same as the scope
      # `verifiables`.

      # When using a separate table to store verification details,
      # the scope `available_verifiables` should return all records
      # from the separate table because the separate table will
      # always only have records corresponding to replicables that are verifiable.
      # For this, override the scope in the replicable model, e.g. like so in
      # `MergeRequestDiff`,
      # `scope :available_verifiables, -> { joins(:merge_request_diff_detail) }`
      scope :available_verifiables, -> { verifiables }

      # The method is tested but undercoverage task doesn't detect it.
      # :nocov:
      def geo_create_event!
        replicator.geo_handle_after_create if replicator.respond_to?(:geo_handle_after_create)
      rescue StandardError => err
        log_error("Geo replicator after_create_commit failed", err)
      end
      # :nocov:
    end

    class_methods do
      # @param primary_key_in [Range, Replicable] arg to pass to primary_key_in scope
      # @return [ActiveRecord::Relation<Replicable>] everything that should be synced to this
      #         node, restricted by primary key
      def replicables_for_current_secondary(primary_key_in)
        node = ::Gitlab::Geo.current_node

        replicables =
          available_replicables
            .merge(object_storage_scope(node))

        replicables
          .merge(selective_sync_scope(node, replicables: replicables))
          .primary_key_in(primary_key_in)
      end

      # @return [ActiveRecord::Relation<Replicable>] scope observing object storage settings of the given node
      def object_storage_scope(node)
        return all unless object_storable?
        return all if node.primary? && Feature.enabled?(:geo_object_storage_verification)
        return all if node.secondary? && node.sync_object_storage?

        with_files_stored_locally
      end

      def object_storable?
        self.respond_to?(:with_files_stored_locally)
      end

      # @return [ActiveRecord::Relation<Replicable>] scope observing selective sync settings of the given node
      def selective_sync_scope(node, **params)
        raise NotImplementedError, "#{self.name} does not implement #{__method__}"
      end
    end

    # @return [String] human-readable title. E.g. "Package File"
    # Override in each model that includes this concern
    def self.replicable_title
      raise NotImplementedError
    end

    # @return [String] pluralized human-readable title. E.g. "Package Files"
    # Override in each model that includes this concern
    def self.replicable_title_plural
      raise NotImplementedError
    end

    def in_replicables_for_current_secondary?
      self.class.replicables_for_current_secondary(self).exists?
    end
    strong_memoize_attr :in_replicables_for_current_secondary?
  end
end
