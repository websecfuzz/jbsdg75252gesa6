# frozen_string_literal: true

module Types
  module WorkItems
    module Widgets
      module TimeTracking
        # rubocop:disable Graphql/AuthorizeTypes -- we already authorize the work item itself
        class TimeTrackingType < BaseObject
          graphql_name 'WorkItemWidgetTimeTracking'
          description 'Represents the time tracking widget on the work item'

          implements ::Types::WorkItems::WidgetInterface

          field :human_readable_attributes, ::Types::WorkItems::Widgets::TimeTracking::HumanReadableAttributesType,
            null: true, resolver_method: :object,
            description: 'Human-readable attributes of the work item.'

          field :time_estimate, GraphQL::Types::Int,
            null: true,
            description: 'Time estimate of the work item.'
          field :total_time_spent, GraphQL::Types::Int,
            null: true,
            description: 'Total time (in seconds) reported as spent on the work item.'

          field :timelogs, ::Types::WorkItems::Widgets::TimeTracking::TimelogType.connection_type,
            null: true,
            description: 'Timelogs on the work item.'
        end
        # rubocop:enable Graphql/AuthorizeTypes
      end
    end
  end
end
