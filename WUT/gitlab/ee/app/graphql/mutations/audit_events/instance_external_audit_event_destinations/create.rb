# frozen_string_literal: true

module Mutations
  module AuditEvents
    module InstanceExternalAuditEventDestinations
      class Create < Base
        graphql_name 'InstanceExternalAuditEventDestinationCreate'

        include ::AuditEvents::LegacyDestinationSyncHelper

        authorize :admin_instance_external_audit_events

        argument :destination_url, GraphQL::Types::String,
          required: true,
          description: 'Destination URL.'

        argument :name, GraphQL::Types::String,
          required: false,
          description: 'Destination name.'

        field :instance_external_audit_event_destination,
          ::Types::AuditEvents::InstanceExternalAuditEventDestinationType,
          null: true,
          description: 'Destination created.'

        def resolve(destination_url:, name: nil)
          destination = ::AuditEvents::InstanceExternalAuditEventDestination.new(destination_url: destination_url,
            name: name)

          if destination.save
            audit(destination, action: :create)
            create_stream_destination(legacy_destination_model: destination, category: :http, is_instance: true)
          end

          {
            instance_external_audit_event_destination: (destination if destination.persisted?),
            errors: Array(destination.errors)
          }
        end
      end
    end
  end
end
