# frozen_string_literal: true

module EE
  module Projects
    module WikiRepository
      extend ActiveSupport::Concern

      prepended do
        include ::Geo::ReplicableModel
        include ::Geo::VerifiableModel

        delegate :create_wiki, :repository_storage, :wiki, to: :project
        delegate :repository, to: :wiki

        delegate(*::Geo::VerificationState::VERIFICATION_METHODS, to: :wiki_repository_state)

        with_replicator ::Geo::ProjectWikiRepositoryReplicator

        has_one :wiki_repository_state,
          class_name: 'Geo::WikiRepositoryState',
          foreign_key: :project_wiki_repository_id,
          inverse_of: :project_wiki_repository,
          autosave: false

        scope :available_verifiables, -> { joins(:wiki_repository_state) }

        scope :checksummed, -> {
          joins(:wiki_repository_state).where.not(wiki_repository_states: { verification_checksum: nil })
        }

        scope :not_checksummed, -> {
          joins(:wiki_repository_state).where(wiki_repository_states: { verification_checksum: nil })
        }

        scope :with_verification_state, ->(state) {
          joins(:wiki_repository_state)
            .where(wiki_repository_states: { verification_state: verification_state_value(state) })
        }

        scope :project_id_in, ->(ids) { where(project_id: ids) }

        def verification_state_object
          wiki_repository_state
        end
      end

      class_methods do
        extend ::Gitlab::Utils::Override

        # @return [ActiveRecord::Relation<LfsObject>] scope observing selective
        #         sync settings of the given node
        override :selective_sync_scope
        def selective_sync_scope(node, **params)
          return all unless node.selective_sync?

          # The primary_key_in in replicables_for_current_secondary method is at most a range
          # of IDs with a maximum of 10_000 records between them.
          replicables = params.fetch(:replicables, none)
          replicables_project_ids = replicables.distinct.pluck(:project_id)
          selective_projects_ids = ::Project.selective_sync_scope(node).id_in(replicables_project_ids).pluck_primary_key

          project_id_in(selective_projects_ids)
        end

        override :verification_state_model_key
        def verification_state_model_key
          :project_wiki_repository_id
        end

        override :verification_state_table_class
        def verification_state_table_class
          Geo::WikiRepositoryState
        end
      end

      # Geo checks this method in FrameworkRepositorySyncService to avoid
      # snapshotting repositories using object pools
      def pool_repository
        nil
      end

      def wiki_repository_state
        super || build_wiki_repository_state
      end
    end
  end
end
