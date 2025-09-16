# frozen_string_literal: true

module Namespaces
  module Storage
    module NamespaceLimit
      class EmailNotificationService
        def self.execute(namespace)
          new.execute(namespace)
        end

        def execute(namespace)
          return unless namespace.root_storage_statistics
          return unless ::Namespaces::Storage::NamespaceLimit::Enforcement.enforce_limit?(namespace)

          root_storage_size = namespace.root_storage_size
          level = notification_level(root_storage_size)
          last_level = namespace.root_storage_statistics.notification_level.to_sym

          return if level == last_level

          send_notification(level, namespace, root_storage_size)
          update_notification_level(level, namespace)
        end

        private

        def notification_level(root_storage_size)
          case root_storage_size.usage_ratio
          when 0...0.7 then :storage_remaining
          when 0.7...0.85 then :caution
          when 0.85...0.95 then :warning
          when 0.95...1 then :danger
          when 1..Float::INFINITY then :exceeded
          end
        end

        def owners_emails(namespace)
          if namespace.is_a?(::Group)
            namespace.pluck_member_user(:email, filters: { access_level: GroupMember::OWNER })
          else
            namespace.owners.map(&:email)
          end
        end

        def send_notification(level, namespace, root_storage_size)
          return if level == :storage_remaining

          owner_emails = owners_emails(namespace)
          usage_values = {
            current_size: root_storage_size.current_size,
            limit: root_storage_size.limit,
            usage_ratio: root_storage_size.usage_ratio
          }

          if level == :exceeded
            NamespaceLimitMailer.notify_out_of_storage(
              namespace: namespace,
              recipients: owner_emails,
              usage_values: usage_values).deliver_later
          else
            NamespaceLimitMailer.notify_limit_warning(
              namespace: namespace,
              recipients: owner_emails,
              usage_values: usage_values).deliver_later
          end
        end

        def update_notification_level(level, namespace)
          namespace.root_storage_statistics.update!(notification_level: level)
        end
      end
    end
  end
end
