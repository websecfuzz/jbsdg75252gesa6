# frozen_string_literal: true

module Namespaces
  module Storage
    class NamespaceLimitMailer < ApplicationMailer
      include ::Namespaces::StorageHelper
      include EmailsHelper
      include NamespacesHelper
      include GitlabRoutingHelper

      helper EmailsHelper
      helper ::Namespaces::StorageHelper

      layout 'mailer'

      def notify_out_of_storage(namespace:, recipients:, usage_values:)
        @namespace = namespace
        @usage_quotas_url = usage_quotas_url(namespace, anchor: 'storage-quota-tab')
        @buy_storage_url = buy_storage_url(namespace)
        @current_size = usage_values[:current_size]
        @limit = usage_values[:limit]
        @usage_ratio = usage_values[:usage_ratio]

        mail_with_locale(
          bcc: recipients,
          subject: safe_format(
            s_("NamespaceStorage|Action required: Storage has been exceeded for %{namespace_name}"),
            { namespace_name: namespace.name }
          )
        )
      end

      def notify_limit_warning(namespace:, recipients:, usage_values:)
        @namespace = namespace
        @usage_quotas_url = usage_quotas_url(namespace, anchor: 'storage-quota-tab')
        @buy_storage_url = buy_storage_url(namespace)
        @current_size = usage_values[:current_size]
        @limit = usage_values[:limit]
        @usage_ratio = usage_values[:usage_ratio]

        mail_with_locale(
          bcc: recipients,
          subject: safe_format(
            s_("NamespaceStorage|You have used %{used_storage_percentage} of the storage quota for %{namespace_name}"),
            { used_storage_percentage: used_storage_percentage(@usage_ratio), namespace_name: namespace.name }
          )
        )
      end
    end
  end
end
