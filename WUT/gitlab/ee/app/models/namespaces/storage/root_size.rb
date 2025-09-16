# frozen_string_literal: true

module Namespaces
  module Storage
    class RootSize
      CURRENT_SIZE_CACHE_KEY = 'root_storage_current_size'
      EXPIRATION_TIME = 10.minutes
      LIMIT_CACHE_NAME = 'root_storage_size_limit'
      DASHBOARD_LIMIT_CACHE_NAME = 'root_dashboard_size_limit'

      def initialize(root_namespace)
        @root_namespace = root_namespace.root_ancestor # just in case the true root isn't passed
      end

      def above_size_limit?
        return false unless valid_enforcement?
        return false unless usage_ratio > 1

        update_first_enforcement_timestamp
        update_last_enforcement_timestamp

        true
      end

      def usage_ratio
        return 0 if limit == 0

        current_size.to_f / limit
      end

      def current_size
        @current_size ||= Rails.cache.fetch(current_size_cache_key, expires_in: EXPIRATION_TIME) do
          root_storage_statistics&.cost_factored_storage_size || 0
        end
      end

      def limit
        # https://docs.gitlab.com/ee/user/storage_usage_quotas#namespace-storage-limit
        @limit ||= Rails.cache.fetch(limit_cache_key, expires_in: EXPIRATION_TIME) do
          enforceable_storage_limit.megabytes +
            root_namespace.additional_purchased_storage_size.megabytes
        end
      end

      def dashboard_limit
        @dashboard_limit ||= Rails.cache.fetch(dashboard_limit_cache_key, expires_in: EXPIRATION_TIME) do
          root_namespace.actual_limits.storage_size_limit.megabytes +
            root_namespace.additional_purchased_storage_size.megabytes
        end
      end

      def remaining_storage_size
        [limit - current_size, 0].max
      end

      def valid_enforcement?
        enforce_limit?
      end

      def enforce_limit?
        ::Namespaces::Storage::NamespaceLimit::Enforcement.enforce_limit?(root_namespace)
      end

      alias_method :enabled?, :enforce_limit?

      def error_message
        message_params = { namespace_name: root_namespace.name }

        @error_message_object ||=
          ::EE::Gitlab::NamespaceStorageSizeErrorMessage.new(checker: self, message_params: message_params)
      end

      def exceeded_size(change_size = 0)
        size = current_size + change_size - limit

        [size, 0].max
      end

      def changes_will_exceed_size_limit?(change_size, project)
        change_size *= ::Namespaces::Storage::CostFactor.cost_factor_for(project)

        limit != 0 && exceeded_size(change_size) > 0
      end

      def enforcement_type
        :namespace_storage_limit
      end

      private

      attr_reader :root_namespace

      delegate :gitlab_subscription, :root_storage_statistics, to: :root_namespace

      def current_size_cache_key
        [
          root_storage_statistics&.cache_key_with_version,
          'namespaces',
          root_namespace.id,
          CURRENT_SIZE_CACHE_KEY
        ].compact
      end

      def limit_cache_key
        [
          root_namespace.actual_limits.cache_key_with_version,
          'namespaces',
          root_namespace.id,
          limit_cache_name
        ]
      end

      def dashboard_limit_cache_key
        [
          root_namespace.actual_limits.cache_key_with_version,
          'namespaces',
          root_namespace.id,
          DASHBOARD_LIMIT_CACHE_NAME
        ]
      end

      def enforceable_storage_limit
        ::Namespaces::Storage::NamespaceLimit::Enforcement.enforceable_storage_limit(root_namespace)
      end

      def limit_cache_name
        LIMIT_CACHE_NAME
      end

      def update_first_enforcement_timestamp
        Rails.cache.fetch(['namespaces', root_namespace.id, 'first_enforcement_tracking'], expires_in: 7.days) do
          namespace_limit = root_namespace.namespace_limit

          next if namespace_limit.first_enforced_at.present?

          namespace_limit.update(first_enforced_at: Time.current)
        end
      end

      def update_last_enforcement_timestamp
        Rails.cache.fetch(['namespaces', root_namespace.id, 'last_enforcement_tracking'], expires_in: 1.day) do
          namespace_limit = root_namespace.namespace_limit

          namespace_limit.update(last_enforced_at: Time.current)
        end
      end
    end
  end
end
