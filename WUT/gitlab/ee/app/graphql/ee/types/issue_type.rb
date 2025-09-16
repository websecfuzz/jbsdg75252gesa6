# frozen_string_literal: true

module EE
  module Types
    module IssueType
      extend ActiveSupport::Concern

      prepended do
        field :epic,
          ::Types::EpicType,
          null: true,
          description: 'Epic to which the issue belongs.',
          deprecated: { reason: 'Replaced by WorkItem type', milestone: '17.5' }

        field :has_epic, GraphQL::Types::Boolean,
          null: false,
          description: "Indicates if the issue belongs to an epic.
            Can return true and not show an associated epic when the user has no access to the epic.",
          method: :has_epic?

        field :has_parent, GraphQL::Types::Boolean,
          null: false,
          experiment: { milestone: '16.5' },
          description: 'Indicates if the issue has a parent work item.',
          method: :has_parent_link?

        field :iteration, ::Types::IterationType, null: true, description: 'Iteration of the issue.'

        field :weight, GraphQL::Types::Int, null: true, description: 'Weight of the issue.'

        field :blocked, GraphQL::Types::Boolean, null: false, description: 'Indicates the issue is blocked.'

        field :blocking_count, GraphQL::Types::Int,
          null: false, method: :blocking_issues_count,
          description: 'Count of issues the issue is blocking.'

        field :blocked_by_count, GraphQL::Types::Int,
          null: true, description: 'Count of issues blocking the issue.'

        field :blocked_by_issues, ::Types::IssueType.connection_type,
          null: true, complexity: 5,
          description: 'Issues blocking the issue.'

        field :health_status, ::Types::HealthStatusEnum,
          null: true, description: 'Current health status.'

        field :status_page_published_incident, GraphQL::Types::Boolean,
          null: true,
          description: 'Indicates whether an issue is published to the status page.'

        field :sla_due_at, ::Types::TimeType, null: true, description: 'Timestamp of when the issue SLA expires.'

        field :metric_images, [::Types::MetricImageType],
          null: true,
          description: 'Metric images associated to the issue.'

        field :escalation_policy, ::Types::IncidentManagement::EscalationPolicyType,
          null: true,
          description: 'Escalation policy associated with the issue. Available for issues which support escalation.'

        field :issuable_resource_links, ::Types::IncidentManagement::IssuableResourceLinkType.connection_type,
          null: true,
          description: 'Issuable resource links of the incident issue.',
          resolver: ::Resolvers::IncidentManagement::IssuableResourceLinksResolver

        field :related_vulnerabilities, ::Types::VulnerabilityType.connection_type,
          null: true,
          description: 'Related vulnerabilities of the issue.'

        field :status, ::Types::WorkItems::StatusType,
          null: true,
          description: 'Status of the issue.',
          experiment: { milestone: '18.0' },
          resolver: ::Resolvers::WorkItems::Statuses::StatusResolver

        def iteration
          ::Gitlab::Graphql::Loaders::BatchModelLoader.new(::Iteration, object.sprint_id).find
        end

        def weight
          object.weight_available? ? object.weight : nil
        end

        def blocked
          ::Gitlab::Graphql::Aggregations::Issues::LazyLinksAggregate.new(context, object.id) do |count|
            (count || 0) > 0
          end
        end

        def blocked_by_count
          ::Gitlab::Graphql::Aggregations::Issues::LazyLinksAggregate.new(context, object.id) do |count|
            count || 0
          end
        end

        def blocked_by_issues
          object.blocked_by_issues_for(current_user)
        end

        def health_status
          object.supports_health_status? ? object.health_status : nil
        end

        def escalation_policy
          object.escalation_policies_available? ? object.escalation_status&.policy : nil
        end
      end
    end
  end
end
