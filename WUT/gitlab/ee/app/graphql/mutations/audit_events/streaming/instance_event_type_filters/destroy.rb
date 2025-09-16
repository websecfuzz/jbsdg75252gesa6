# frozen_string_literal: true

module Mutations
  module AuditEvents
    module Streaming
      module InstanceEventTypeFilters
        class Destroy < BaseEventTypeFilters::BaseDestroy
          graphql_name 'AuditEventsStreamingDestinationInstanceEventsRemove'

          authorize :admin_instance_external_audit_events

          argument :destination_id, ::Types::GlobalIDType[::AuditEvents::InstanceExternalAuditEventDestination],
            required: true,
            description: 'Destination id.'
        end
      end
    end
  end
end
