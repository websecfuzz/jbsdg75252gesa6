# frozen_string_literal: true

module GitlabSubscriptions
  module API
    module Entities
      module Internal
        class Namespace < ::API::Entities::NamespaceBasic
          has_gitlab_subscription = ->(namespace) { namespace.gitlab_subscription.present? }
          namespace_for_group = ->(namespace) { namespace.kind == 'group' }

          expose :shared_runners_minutes_limit, documentation: { type: 'integer', example: 133 }
          expose :extra_shared_runners_minutes_limit, documentation: { type: 'integer', example: 133 }
          expose :additional_purchased_storage_size, documentation: { type: 'integer', example: 1000 }
          expose :additional_purchased_storage_ends_on, documentation: { type: 'date', example: '2022-06-18' }
          expose :billable_members_count, documentation: { type: 'integer', example: 2 } do |namespace, options|
            namespace.billable_members_count(options[:requested_hosted_plan])
          end

          expose :seats_in_use, documentation: { type: 'integer', example: 5 },
            if: has_gitlab_subscription do |namespace, _|
            namespace.gitlab_subscription.seats_in_use
          end

          expose :max_seats_used, documentation: { type: 'integer', example: 100 },
            if: has_gitlab_subscription do |namespace, _|
            namespace.gitlab_subscription.max_seats_used
          end

          expose :max_seats_used_changed_at, documentation: { type: 'date', example: '2022-06-18' },
            if: has_gitlab_subscription do |namespace, _|
            namespace.gitlab_subscription.max_seats_used_changed_at
          end

          expose :end_date, documentation: { type: 'date', example: '2022-06-18' },
            if: has_gitlab_subscription do |namespace, _|
            namespace.gitlab_subscription.end_date
          end

          expose :plan, documentation: { type: 'string', example: 'default' } do |namespace, _|
            namespace.actual_plan_name
          end

          expose :trial_ends_on, documentation: { type: 'date', example: '2022-06-18' } do |namespace, _|
            namespace.trial_ends_on
          end

          expose :trial, documentation: { type: 'boolean' } do |namespace, _|
            namespace.trial?
          end

          expose :members_count_with_descendants, documentation: { type: 'integer', example: 5 },
            if: namespace_for_group do |namespace, _|
            namespace.users_with_descendants.count
          end

          expose :root_repository_size, documentation: { type: 'integer', example: 123 },
            if: namespace_for_group do |namespace, _|
            namespace.root_storage_statistics&.repository_size
          end

          expose :projects_count, documentation: { type: 'integer', example: 123 },
            if: namespace_for_group do |namespace, _|
            namespace.all_projects.count
          end
        end
      end
    end
  end
end
