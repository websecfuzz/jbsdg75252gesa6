# frozen_string_literal: true

module EE
  module Ci
    module Runner
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      MOST_ACTIVE_RUNNERS_BUILDS_LIMIT = 1000

      prepended do
        has_one :cost_settings, class_name: 'Ci::Minutes::CostSetting', foreign_key: :runner_id, inverse_of: :runner
        has_many :hosted_runner_monthly_usages,
          class_name: 'Ci::Minutes::GitlabHostedRunnerMonthlyUsage',
          inverse_of: :runner
        has_many :instance_runner_monthly_usages,
          class_name: 'Ci::Minutes::InstanceRunnerMonthlyUsage',
          inverse_of: :runner
        has_one :hosted_registration, class_name: 'Ci::HostedRunner', inverse_of: :runner

        scope :with_top_running_builds_of_runner_type, ->(runner_type) do
          most_active_runners(->(relation) { relation.where(runner_type: runner_type) })
        end

        scope :with_top_running_builds_by_namespace_id, ->(namespace_id) do
          most_active_runners(
            ->(relation) { relation.where(runner_type: :group_type).where(runner_owner_namespace_xid: namespace_id) }
          )
        end

        # NOTE: This scope is meant to be used with scopes that leverage the most_active_runners method
        scope :order_most_active_desc, -> do
          group(:id, :runner_type).reorder('COUNT(limited_builds.runner_id) DESC NULLS LAST', arel_table['id'].desc)
        end

        def self.any_shared_runners_with_enabled_cost_factor?(project)
          if project.public?
            instance_type.where('public_projects_minutes_cost_factor > 0').exists?
          else
            instance_type.where('private_projects_minutes_cost_factor > 0').exists?
          end
        end
      end

      def cost_factor_for_project(project)
        cost_factor.for_project(project)
      end

      def cost_factor_enabled?(project)
        cost_factor.enabled?(project)
      end

      def allowed_plan_names
        ::Plan.names_for_ids(allowed_plan_ids)
      end

      def allowed_plans=(names)
        self.allowed_plan_ids = ::Plan.ids_for_names(names)
      end

      # On a dedicated installation we use a table to track which runners are hosted at registration time
      # TODO (issue#533869): after 18.0 this should change to
      # return true if ::Gitlab::CurrentSettings.gitlab_dedicated_instance? &&
      #   hosted_registration.present?
      override :dedicated_gitlab_hosted?
      def dedicated_gitlab_hosted?
        return true if ::Gitlab::CurrentSettings.gitlab_dedicated_instance? &&
          creator&.admin_bot?

        super
      end

      private

      def cost_factor
        strong_memoize(:cost_factor) do
          ::Gitlab::Ci::Minutes::CostFactor.new(runner_matcher)
        end
      end

      class_methods do
        def most_active_runners(inner_query_fn = nil)
          inner_query = ::Ci::RunningBuild.select(
            'runner_id',
            Arel.sql('ROW_NUMBER() OVER (PARTITION BY runner_id ORDER BY runner_id) AS rn')
          )
          inner_query = inner_query_fn.call(inner_query) if inner_query_fn

          joins(
            <<~SQL
            INNER JOIN (#{inner_query.to_sql}) AS "limited_builds" ON "limited_builds"."runner_id" = "ci_runners"."id"
                                               AND "limited_builds".rn <= #{MOST_ACTIVE_RUNNERS_BUILDS_LIMIT}
            SQL
          )
        end
      end
    end
  end
end
