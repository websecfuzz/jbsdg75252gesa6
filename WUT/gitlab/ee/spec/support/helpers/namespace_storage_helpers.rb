# frozen_string_literal: true

module NamespaceStorageHelpers
  def set_enforcement_limit(namespace, megabytes:)
    namespace.actual_plan.actual_limits.update!(enforcement_limit: megabytes)
  end

  def set_used_storage(namespace, megabytes:)
    namespace.root_storage_statistics.update!(storage_size: megabytes.megabytes)
  end

  def set_dashboard_limit(namespace, megabytes:, enabled: true)
    limits = namespace.actual_limits

    limits.storage_size_limit = megabytes
    limits.dashboard_limit_enabled_at = namespace.created_at - 1.day if enabled

    limits.save!
  end

  def set_notification_limit(namespace, megabytes:)
    namespace.root_ancestor.actual_plan.actual_limits.update!(notification_limit: megabytes)
  end

  def enforce_namespace_storage_limit(root_namespace)
    stub_ee_application_setting(should_check_namespace_plan: true)
    stub_ee_application_setting(enforce_namespace_storage_limit: true)
    stub_ee_application_setting(automatic_purchased_storage_allocation: true)
    stub_feature_flags(namespace_storage_limit: root_namespace)
    stub_saas_features(namespaces_storage_limit: true, gitlab_com_subscriptions: true)

    allow(::Namespaces::Storage::NamespaceLimit::Enforcement).to receive(:enforceable_namespace?).and_return true
  end
end
