# frozen_string_literal: true

module EE
  module AuditEvents
    module UserAuditEvent
      include ::Gitlab::Utils::StrongMemoize
      include ::AuditEvents::CommonAuditEventStreamable

      attr_accessor :root_group_entity_id
      attr_writer :entity, :user

      def user
        lazy_user
      end
      strong_memoize_attr :user

      def entity
        user
      end
      strong_memoize_attr :entity

      def entity_id
        return if entity.is_a?(::Gitlab::Audit::NullEntity)

        entity.id if entity.respond_to?(:id)
      end

      def entity_type
        "User"
      end

      def present
        AuditEventPresenter.new(self)
      end

      def root_group_entity
        nil
      end
      strong_memoize_attr :root_group_entity

      private

      def lazy_user
        BatchLoader.for(user_id)
                  .batch(default_value: ::Gitlab::Audit::NullEntity.new) do |ids, loader|
          ::User.where(id: ids).find_each { |record| loader.call(record.id, record) }
        end
      end
    end
  end
end
