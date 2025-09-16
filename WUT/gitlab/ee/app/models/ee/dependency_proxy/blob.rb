# frozen_string_literal: true

module EE
  module DependencyProxy
    module Blob
      extend ActiveSupport::Concern

      prepended do
        include ::Geo::ReplicableModel
        include ::Geo::VerifiableModel

        delegate(*::Geo::VerificationState::VERIFICATION_METHODS, to: :dependency_proxy_blob_state)

        with_replicator Geo::DependencyProxyBlobReplicator

        has_one :dependency_proxy_blob_state,
          autosave: false,
          inverse_of: :dependency_proxy_blob,
          class_name: 'Geo::DependencyProxyBlobState',
          foreign_key: :dependency_proxy_blob_id

        scope :with_verification_state, ->(state) do
          joins(:dependency_proxy_blob_state)
            .where(dependency_proxy_blob_states: { verification_state: verification_state_value(state) })
        end
        scope :checksummed,
          -> do
            joins(:dependency_proxy_blob_state).where.not(dependency_proxy_blob_states: { verification_checksum: nil })
          end
        scope :not_checksummed,
          -> do
            joins(:dependency_proxy_blob_state).where(dependency_proxy_blob_states: { verification_checksum: nil })
          end

        scope :available_verifiables, -> { joins(:dependency_proxy_blob_state) }

        scope :group_id_in, ->(ids) { joins(:group).merge(::Namespace.id_in(ids)) }

        def verification_state_object
          dependency_proxy_blob_state
        end
      end

      class_methods do
        extend ::Gitlab::Utils::Override

        override :verification_state_table_class
        def verification_state_table_class
          Geo::DependencyProxyBlobState
        end

        override :selective_sync_scope
        def selective_sync_scope(node, **_params)
          return all unless node.selective_sync?
          return group_id_in(node.namespace_ids) if node.selective_sync_by_namespaces?
          return group_id_in(node.namespaces_for_group_owned_replicables.select(:id)) if node.selective_sync_by_shards?

          none
        end
      end

      def dependency_proxy_blob_state
        super || build_dependency_proxy_blob_state
      end
    end
  end
end
