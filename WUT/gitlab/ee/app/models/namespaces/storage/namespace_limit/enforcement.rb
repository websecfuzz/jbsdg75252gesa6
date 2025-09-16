# frozen_string_literal: true

# Handles Namespace Storage Enforcement
#
# This is not yet released and is NOT in use anywhere. Docs:
# - https://internal.gitlab.com/handbook/engineering/fulfillment/namespace-storage-enforcement/
# - Feature Flag: namespace_storage_limit
#
# This handles the enforcement logic for all storage types at namespace level for GitLab.com.
# All storage types for all projects are aggregated to the root namespace and will be used to
# enforce a limit that is set via PlanLimits.
#
module Namespaces
  module Storage
    module NamespaceLimit
      module Enforcement
        extend self

        def enforce_limit?(namespace)
          root_namespace = namespace.root_ancestor

          ::Gitlab::CurrentSettings.enforce_namespace_storage_limit? &&
            ::Gitlab::CurrentSettings.automatic_purchased_storage_allocation? &&
            ::Feature.enabled?(:namespace_storage_limit, root_namespace) &&
            enforceable_namespace?(root_namespace)
        end

        def show_pre_enforcement_alert?(namespace)
          root_namespace = namespace.root_ancestor

          return false unless in_pre_enforcement_phase?(root_namespace)
          return false unless over_pre_enforcement_notification_limit?(root_namespace)

          update_pre_enforcement_timestamp(root_namespace)

          true
        end

        def over_pre_enforcement_notification_limit?(root_namespace)
          return false if root_namespace.storage_limit_exclusion.present?

          # The storage usage limit used for comparing whether to display the phased notification or not.
          # It should not be confused with the dashboard limit called storage_size_limit.
          # This particular setting is saved in megabytes, so we should utilize the '.megabytes' method.
          notification_limit = root_namespace.actual_plan.actual_limits.notification_limit.megabytes
          return false unless notification_limit > 0

          total_storage = ::Namespaces::Storage::RootSize.new(root_namespace).current_size
          purchased_storage = (root_namespace.additional_purchased_storage_size || 0).megabytes

          total_storage > (notification_limit + purchased_storage)
        end

        def enforceable_storage_limit(root_namespace)
          # no limit for excluded namespaces
          return 0 if root_namespace.storage_limit_exclusion.present?

          plan_limit = root_namespace.actual_limits

          # use dashboard limit (storage_size_limit) if:
          # - enabled (determined by timestamp)
          # - namespace was created after the timestamp
          return plan_limit.storage_size_limit if dashboard_limit_applicable?(root_namespace, plan_limit)

          # otherwise, we use enforcement limit as it's either not set (default db value is 0)
          # or it has value to enforce
          plan_limit.enforcement_limit
        end

        def in_pre_enforcement_phase?(root_namespace)
          # a Namespace is in the pre-enforcement phase if all the following are true:
          # - the application settings for rollout are enabled
          # - the namespace is not on a paid plan
          # - their storage usage is under the enforcement limit
          # - the namespace is not being excluded from storage limits

          return false unless ::Feature.enabled?(:namespace_storage_limit_show_preenforcement_banner, root_namespace)
          return false unless ::Gitlab::Saas.feature_available?(:namespaces_storage_limit)
          return false unless ::Gitlab::CurrentSettings.automatic_purchased_storage_allocation?
          return false if root_namespace.paid?

          # above_size_limit? will return true if enforcement is enabled and the
          # namespace is above the applicable limit
          return false if ::Namespaces::Storage::RootSize.new(root_namespace).above_size_limit?

          true
        end

        def in_enforcement_rollout?(root_namespace)
          return false unless enforce_limit?(root_namespace)
          return false if root_namespace.storage_limit_exclusion.present?

          plan_limit = root_namespace.actual_limits
          return false if dashboard_limit_applicable?(root_namespace, plan_limit)

          enforceable_storage_limit(root_namespace) > plan_limit.storage_size_limit
        end

        private

        def update_pre_enforcement_timestamp(root_namespace)
          Rails.cache.fetch(['namespaces', root_namespace.id, 'pre_enforcement_tracking'], expires_in: 7.days) do
            namespace_limit = root_namespace.namespace_limit

            next if namespace_limit.pre_enforcement_notification_at.present?

            namespace_limit.update(pre_enforcement_notification_at: Time.current)
          end
        end

        def enforceable_namespace?(root_namespace)
          return false if root_namespace.opensource_plan?
          return false if root_namespace.paid?

          enforceable_storage_limit(root_namespace) > 0
        end

        def dashboard_limit_applicable?(root_namespace, plan_limit)
          plan_limit.dashboard_storage_limit_enabled? &&
            root_namespace.created_at > plan_limit.dashboard_limit_enabled_at
        end
      end
    end
  end
end
