# frozen_string_literal: true

module EE
  module Types
    module Issues
      module NegatedIssueFilterInputType
        extend ActiveSupport::Concern

        prepended do
          argument :epic_id, GraphQL::Types::String,
            required: false,
            description: 'ID of an epic not associated with the issues.'
          argument :weight, GraphQL::Types::String,
            required: false,
            description: 'Weight not applied to the issue.'
          argument :iteration_id, [::GraphQL::Types::ID],
            required: false,
            description: 'List of iteration Global IDs not applied to the issue.'
          argument :iteration_wildcard_id, ::Types::IterationWildcardIdEnum,
            required: false,
            description: 'Filter by negated iteration ID wildcard.'
          argument :health_status_filter, [::Types::HealthStatusEnum],
            required: false,
            description: 'Health status not applied to the issue.
                    Includes issues where health status is not set.'

          validates mutually_exclusive: [:iteration_id, :iteration_wildcard_id]
        end
      end
    end
  end
end
