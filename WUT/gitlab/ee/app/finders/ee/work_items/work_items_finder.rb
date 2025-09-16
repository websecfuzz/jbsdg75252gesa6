# frozen_string_literal: true

module EE
  module WorkItems
    module WorkItemsFinder
      extend ::Gitlab::Utils::Override
      include ::Gitlab::Utils::StrongMemoize

      private

      override :use_full_text_search?
      def use_full_text_search?
        # `issue_search_data` table doesn't support group-level work items yet
        return false if include_group_work_items?

        super
      end

      override :by_confidential
      def by_confidential(items)
        return super unless include_group_work_items?

        ::Issues::ConfidentialityFilter.new(
          current_user: current_user,
          params: original_params,
          parent: root_ancestor_group,
          assignee_filter: assignee_filter,
          related_groups: related_groups
        ).filter(items)
      end

      override :by_parent
      def by_parent(items)
        return super unless include_group_work_items?

        relations = [group_namespace_ids, project_namespace_ids].compact

        return items.none if relations.empty?

        namespaces = if relations.one?
                       relations.first
                     else
                       ::Namespace.from_union(relations, remove_duplicates: false)
                     end

        items.in_namespaces_with_cte(namespaces)
      end

      def project_namespace_ids
        projects = accessible_projects
        return if projects.nil?

        accessible_projects.select(:project_namespace_id)
      end

      def group_namespace_ids
        return if params[:project_id] || params[:projects]
        return unless include_group_work_items?

        related_groups_with_access.select(:id)
      end

      def related_groups_with_access
        # If the user is not signed in, we just return public groups
        return related_groups.public_to_user unless current_user

        # If the user is an admin or a member of the root group, they will have read access to all
        # work items in the subgroups so we can skip the expensive permissions check
        if Ability.allowed?(current_user, :read_all_resources) || root_ancestor_group.member?(current_user)
          return related_groups
        end

        ::Group.id_in(
          ::Group.groups_user_can(related_groups, current_user, :read_work_item, same_root: true)
        )
      end

      def related_groups
        if include_ancestors? && include_descendants?
          params.group.self_and_hierarchy
        elsif include_ancestors?
          params.group.self_and_ancestors
        elsif include_descendants?
          params.group.self_and_descendants
        else
          ::Group.id_in(params.group.id)
        end
      end
      strong_memoize_attr :related_groups

      def root_ancestor_group
        include_ancestors? ? params.group.root_ancestor : params.group
      end

      def include_group_work_items?
        params.group? && params.group.supports_group_work_items?
      end

      def with_namespace_cte
        include_group_work_items?
      end
    end
  end
end
