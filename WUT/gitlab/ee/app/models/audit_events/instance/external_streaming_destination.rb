# frozen_string_literal: true

module AuditEvents
  module Instance
    class ExternalStreamingDestination < ApplicationRecord
      include Limitable
      include ExternallyStreamable
      include LegacyDestinationMappable
      include Activatable

      self.limit_name = 'external_audit_event_destinations'
      self.limit_scope = Limitable::GLOBAL_SCOPE
      self.table_name = 'audit_events_instance_external_streaming_destinations'

      validates :name, uniqueness: { scope: [:category] }

      has_many :event_type_filters, class_name: 'AuditEvents::Instance::EventTypeFilter'
      has_many :namespace_filters, class_name: 'AuditEvents::Instance::NamespaceFilter'
    end
  end
end
