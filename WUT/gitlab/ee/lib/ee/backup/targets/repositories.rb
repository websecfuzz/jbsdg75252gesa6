# frozen_string_literal: true

module EE
  module Backup
    module Targets
      module Repositories
        extend ::Gitlab::Utils::Override

        private

        def group_relation
          scope = ::Group.includes(:route, group_wiki_repository: :shard) # rubocop: disable CodeReuse/ActiveRecord -- legacy code
          scope = scope.id_in(GroupWikiRepository.for_repository_storage(storages).select(:group_id)) if storages.any?
          scope = scope.where_full_path_in(paths).self_and_descendants if paths.any?
          scope
        end

        def find_groups_in_batches
          group_relation.find_each(batch_size: 100) do |group| # rubocop: disable CodeReuse/ActiveRecord -- legacy code
            yield(group)
          end
        end

        def enqueue_group(group)
          strategy.enqueue(group, ::Gitlab::GlRepository::WIKI)
        end

        override :enqueue_consecutive

        def enqueue_consecutive
          enqueue_consecutive_groups

          super
        end

        def enqueue_consecutive_groups
          find_groups_in_batches do |group|
            enqueue_group(group)
          end
        end
      end
    end
  end
end
