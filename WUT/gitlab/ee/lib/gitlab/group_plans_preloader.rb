# frozen_string_literal: true

module Gitlab
  # Preloading of Plans for one or more groups.
  #
  # This class can be used to efficiently preload the plans of a given list of
  # groups, including any plans the groups may have access to based on their
  # parent groups.
  class GroupPlansPreloader
    # Preloads all the plans for the given Groups.
    #
    # groups - An ActiveRecord::Relation returning a set of Group instances.
    #
    # Returns an Array containing all the Groups, including their preloaded
    # plans.
    def preload(groups)
      return groups unless ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)

      groups_relation = activerecord_relation(groups)

      return if groups_relation.null_relation?

      groups_and_ancestors = groups_and_ancestors_for(groups_relation)
      # A Hash mapping group IDs to their corresponding Group instances.
      groups_map = groups_and_ancestors.index_by(&:id)

      all_plan_ids = Set.new

      plans_map = groups_and_ancestors
        .each_with_object({}) do |group, hash|
          current = group

          while current

            if (plan_id = current.hosted_plan_id)
              hash[group.id] = plan_id
              all_plan_ids << plan_id
            end

            current = groups_map[current.parent_id]
          end
        end

      # Grab all the plans for all the Groups, using only a single query.
      plans = Plan
        .id_in(all_plan_ids.to_a)
        .index_by(&:id)

      # Assign all the plans to the groups that have access to them.
      groups.each do |group|
        group.actual_plan = plans[plans_map[group.id]]
      end
    end

    # Returns an ActiveRecord::Relation that includes the given groups, and all
    # their (recursive) ancestors.
    def groups_and_ancestors_for(groups)
      groups
       .self_and_ancestors
       .join_gitlab_subscription
       .select('namespaces.id', 'namespaces.parent_id', 'gitlab_subscriptions.hosted_plan_id')
    end

    private

    def activerecord_relation(groups)
      if groups.is_a?(ActiveRecord::Relation)
        groups
      else
        Group.id_in(groups)
      end
    end
  end
end
