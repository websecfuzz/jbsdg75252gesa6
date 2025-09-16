# frozen_string_literal: true

module Mutations
  module AuditEvents
    module Streaming
      module BaseEventTypeFilters
        class BaseCreate < BaseMutation
          argument :event_type_filters, [GraphQL::Types::String],
            required: true,
            description: 'List of event type filters to add for streaming.',
            prepare: ->(filters, _ctx) do
              filters.presence || (raise ::Gitlab::Graphql::Errors::ArgumentError,
                'event type filters must be present')
            end

          field :event_type_filters, [GraphQL::Types::String],
            null: true,
            description: 'List of event type filters for the audit event external destination.'

          def resolve(destination_id:, event_type_filters:)
            destination = authorized_find!(id: destination_id)

            response = ::AuditEvents::Streaming::EventTypeFilters::CreateService.new(
              destination: destination,
              event_type_filters: event_type_filters,
              current_user: current_user
            ).execute

            { event_type_filters: destination.event_type_filters, errors: response.errors }
          end
        end
      end
    end
  end
end
