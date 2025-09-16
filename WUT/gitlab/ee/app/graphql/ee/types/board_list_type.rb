# frozen_string_literal: true

module EE
  module Types
    module BoardListType
      extend ActiveSupport::Concern

      prepended do
        field :milestone, ::Types::MilestoneType,
          null: true, description: 'Milestone of the list.'

        field :iteration, ::Types::IterationType,
          null: true, description: 'Iteration of the list.'

        field :max_issue_count, GraphQL::Types::Int,
          null: true, description: 'Maximum number of issues in the list.'

        field :max_issue_weight, GraphQL::Types::Int,
          null: true, description: 'Maximum weight of issues in the list.'

        field :assignee, ::Types::UserType,
          null: true, description: 'Assignee in the list.'

        field :limit_metric, ::EE::Types::ListLimitMetricEnum,
          null: true, description: 'Current limit metric for the list.'

        field :total_issue_weight, GraphQL::Types::BigInt,
          null: true, description: 'Total weight of all issues in the list, encoded as a string.'

        field :status, ::Types::WorkItems::StatusType,
          null: true,
          description: 'Status of the list.',
          experiment: { milestone: '18.0' }

        def milestone
          ::Gitlab::Graphql::Loaders::BatchModelLoader.new(::Milestone, object.milestone_id).find
        end

        def iteration
          ::Gitlab::Graphql::Loaders::BatchModelLoader.new(::Iteration, object.iteration_id).find
        end

        def assignee
          object.assignee? ? object.user : nil
        end

        def total_issue_weight
          metadata[:total_weight]
        end
      end
    end
  end
end
