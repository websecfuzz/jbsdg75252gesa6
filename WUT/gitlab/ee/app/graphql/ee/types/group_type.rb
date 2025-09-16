# frozen_string_literal: true

module EE
  module Types
    module GroupType
      extend ActiveSupport::Concern

      prepended do
        field :epics_enabled, GraphQL::Types::Boolean,
          null: true,
          description: "Indicates if Epics are enabled for namespace.",
          deprecated: {
            reason: 'Replaced by `WorkItem` type. For more information, see [migration guide](https://docs.gitlab.com/api/graphql/epic_work_items_api_migration_guide/)',
            milestone: '17.5'
          }

        field :epic, ::Types::EpicType,
          null: true, description: 'Find a single epic.',
          resolver: ::Resolvers::EpicsResolver.single,
          deprecated: {
            reason: 'Replaced by `WorkItem` type. For more information, see [migration guide](https://docs.gitlab.com/api/graphql/epic_work_items_api_migration_guide/)',
            milestone: '17.5'
          }

        field :epics, ::Types::EpicType.connection_type,
          null: true, description: 'Find epics.',
          extras: [:lookahead],
          resolver: ::Resolvers::EpicsResolver,
          deprecated: {
            reason: 'Replaced by `WorkItem` type. For more information, see [migration guide](https://docs.gitlab.com/api/graphql/epic_work_items_api_migration_guide/)',
            milestone: '17.5'
          }

        field :epic_board, ::Types::Boards::EpicBoardType,
          null: true, description: 'Find a single epic board.',
          resolver: ::Resolvers::Boards::EpicBoardsResolver.single,
          deprecated: { reason: 'Replaced by WorkItem type', milestone: '17.5' }

        field :epic_boards, ::Types::Boards::EpicBoardType.connection_type,
          null: true,
          description: 'Find epic boards.', resolver: ::Resolvers::Boards::EpicBoardsResolver,
          deprecated: { reason: 'Replaced by WorkItem type', milestone: '17.5' }

        field :iterations, ::Types::IterationType.connection_type,
          null: true, description: 'Find iterations.',
          resolver: ::Resolvers::IterationsResolver

        field :iteration_cadences, ::Types::Iterations::CadenceType.connection_type,
          null: true,
          description: 'Find iteration cadences.',
          resolver: ::Resolvers::Iterations::CadencesResolver

        field :ci_queueing_history,
          ::Types::Ci::QueueingHistoryType,
          null: true,
          experiment: { milestone: '16.11' },
          description: "Time taken for CI jobs to be picked up by this group's runners by percentile. " \
            "Available to users with Maintainer role for the group. " \
            'Enable the ClickHouse database backend to use this query.',
          resolver: ::Resolvers::Ci::GroupQueueingHistoryResolver,
          extras: [:lookahead]

        field :runner_cloud_provisioning,
          ::Types::Ci::RunnerCloudProvisioningType,
          null: true,
          experiment: { milestone: '16.10' },
          description: 'Information used for provisioning the runner on a cloud provider. ' \
                       'Returns `null` if the GitLab instance is not a SaaS instance.' do
          argument :provider, ::Types::Ci::RunnerCloudProviderEnum, required: true,
            description: 'Identifier of the cloud provider.'
          argument :cloud_project_id, ::Types::GoogleCloud::ProjectType, required: true,
            description: 'Identifier of the cloud project.'
        end

        field :vulnerabilities, ::Types::VulnerabilityType.connection_type,
          null: true,
          extras: [:lookahead],
          description: 'Vulnerabilities reported on the projects in the group and its subgroups.',
          resolver: ::Resolvers::VulnerabilitiesResolver

        field :vulnerability_scanners, ::Types::VulnerabilityScannerType.connection_type,
          null: true,
          description: 'Vulnerability scanners reported on the project vulnerabilities of the group and ' \
                       'its subgroups.',
          resolver: ::Resolvers::Vulnerabilities::ScannersResolver

        field :vulnerability_identifier_search,
          [GraphQL::Types::String],
          resolver: ::Resolvers::Vulnerabilities::IdentifierSearchResolver,
          null: true,
          description: 'Search for vulnerabilities by identifier.'

        field :vulnerability_namespace_statistic, ::Types::Security::VulnerabilityNamespaceStatisticType,
          null: true,
          description: 'Counts for each vulnerability severity in the group and its subgroups.',
          authorize: :read_vulnerability_statistics,
          skip_type_authorization: :read_vulnerability_statistics

        field :vulnerability_severities_count, ::Types::VulnerabilitySeveritiesCountType,
          null: true,
          description: 'Counts for each vulnerability severity in the group and its subgroups.',
          resolver: ::Resolvers::VulnerabilitySeveritiesCountResolver

        field :vulnerabilities_count_by_day, ::Types::VulnerabilitiesCountByDayType.connection_type,
          null: true,
          description: 'The historical number of vulnerabilities per day for the projects in the group and ' \
                       'its subgroups.',
          resolver: ::Resolvers::VulnerabilitiesCountPerDayResolver

        field :vulnerability_grades, [::Types::VulnerableProjectsByGradeType],
          null: true,
          description: 'Represents vulnerable project counts for each grade.',
          resolver: ::Resolvers::VulnerabilitiesGradeResolver

        field :code_coverage_activities, ::Types::Ci::CodeCoverageActivityType.connection_type,
          null: true,
          description: 'Represents the code coverage activity for this group.',
          resolver: ::Resolvers::Ci::CodeCoverageActivitiesResolver

        field :stats, ::Types::GroupStatsType,
          null: true,
          description: 'Group statistics.',
          method: :itself

        field :billable_members_count, ::GraphQL::Types::Int,
          null: true,
          authorize: :owner_access,
          description: 'Number of billable users in the group.' do
            argument :requested_hosted_plan, String,
              required: false,
              description: 'Plan from which to get billable members.'
          end

        field :dora, ::Types::Analytics::Dora::GroupDoraType,
          null: true,
          method: :itself,
          description: "Group's DORA metrics."

        field :dora_performance_score_counts, ::Types::Analytics::Dora::PerformanceScoreCountType.connection_type,
          null: true,
          resolver: ::Resolvers::Analytics::Dora::PerformanceScoresCountResolver, complexity: 10,
          description: "Group's DORA scores for all projects by DORA key metric for the last complete month."

        field :external_audit_event_destinations,
          ::Types::AuditEvents::ExternalAuditEventDestinationType.connection_type,
          null: true,
          description: 'External locations that receive audit events belonging to the group.',
          authorize: :admin_external_audit_events

        field :external_audit_event_streaming_destinations,
          ::Types::AuditEvents::Group::StreamingDestinationType.connection_type,
          null: true,
          description: 'External destinations that receive audit events belonging to the group.',
          authorize: :admin_external_audit_events,
          experiment: { milestone: '16.11' }

        field :google_cloud_logging_configurations,
          ::Types::AuditEvents::GoogleCloudLoggingConfigurationType.connection_type,
          null: true,
          description: 'Google Cloud logging configurations that receive audit events belonging to the group.',
          authorize: :admin_external_audit_events

        field :merge_request_violations,
          ::Types::ComplianceManagement::MergeRequests::ComplianceViolationType.connection_type,
          null: true,
          description: 'Compliance violations reported on merge requests merged within the group.',
          resolver: ::Resolvers::ComplianceManagement::MergeRequests::GroupComplianceViolationResolver,
          authorize: :read_compliance_violations_report

        field :allow_stale_runner_pruning,
          ::GraphQL::Types::Boolean,
          null: false,
          description: 'Indicates whether to regularly prune stale group runners. Defaults to false.',
          method: :allow_stale_runner_pruning?

        field :enforce_free_user_cap,
          ::GraphQL::Types::Boolean,
          null: true,
          authorize: :owner_access,
          description: 'Indicates whether the group has limited users for a free plan.',
          method: :enforce_free_user_cap?

        field :gitlab_subscriptions_preview_billable_user_change,
          ::Types::GitlabSubscriptions::PreviewBillableUserChangeType,
          null: true,
          complexity: 100,
          description: 'Preview Billable User Changes',
          resolver: ::Resolvers::GitlabSubscriptions::PreviewBillableUserChangeResolver

        field :contributions,
          ::Types::Analytics::ContributionAnalytics::ContributionMetadataType.connection_type,
          null: true,
          resolver: ::Resolvers::Analytics::ContributionAnalytics::ContributionsResolver,
          description: 'Provides the aggregated contributions by users within the group and its subgroups',
          authorize: :read_group_contribution_analytics,
          connection_extension: ::Gitlab::Graphql::Extensions::ForwardOnlyExternallyPaginatedArrayExtension

        field :flow_metrics,
          ::Types::Analytics::CycleAnalytics::FlowMetrics[:group],
          null: true,
          description: 'Flow metrics for value stream analytics.',
          method: :itself,
          authorize: :read_cycle_analytics,
          experiment: { milestone: '15.10' }

        field :ai_metrics,
          ::Types::Analytics::AiMetrics::NamespaceMetricsType,
          null: true,
          description: 'AI-related metrics.',
          resolver: ::Resolvers::Analytics::AiMetrics::NamespaceMetricsResolver,
          extras: [:lookahead],
          experiment: { milestone: '16.11' }

        field :ai_usage_data,
          ::Types::Analytics::AiUsage::AiUsageDataType,
          description: 'AI-related data.',
          resolver_method: :object,
          experiment: { milestone: '17.5' }

        field :ai_user_metrics,
          ::Types::Analytics::AiMetrics::UserMetricsType.connection_type,
          null: true,
          description: 'AI-related user metrics.',
          resolver: ::Resolvers::Analytics::AiMetrics::UserMetricsResolver,
          experiment: { milestone: '17.5' }

        field :project_compliance_standards_adherence,
          ::Types::Projects::ComplianceStandards::AdherenceType.connection_type,
          null: true,
          description: 'Compliance standards adherence for the projects in a group and its subgroups.',
          resolver: ::Resolvers::Projects::ComplianceStandards::GroupAdherenceResolver,
          authorize: :read_compliance_adherence_report

        field :value_stream_dashboard_usage_overview,
          ::Types::Analytics::ValueStreamDashboard::CountType,
          null: true,
          resolver: ::Resolvers::Analytics::ValueStreamDashboard::CountResolver,
          description: 'Aggregated usage counts within the group',
          authorize: :read_group_analytics_dashboards,
          experiment: { milestone: '16.4' }

        field :customizable_dashboards,
          ::Types::Analytics::Dashboards::DashboardType.connection_type,
          description: 'Customizable dashboards for the group.',
          null: true,
          calls_gitaly: true,
          resolver: ::Resolvers::Analytics::Dashboards::DashboardsResolver

        field :customizable_dashboard_visualizations, ::Types::Analytics::Dashboards::VisualizationType.connection_type,
          description: 'Visualizations of the group or associated configuration project.',
          null: true,
          calls_gitaly: true,
          resolver: ::Resolvers::Analytics::Dashboards::VisualizationsResolver

        field :amazon_s3_configurations,
          ::Types::AuditEvents::AmazonS3ConfigurationType.connection_type,
          null: true,
          description: 'Amazon S3 configurations that receive audit events belonging to the group.',
          authorize: :admin_external_audit_events

        field :member_roles, ::Types::MemberRoles::MemberRoleType.connection_type,
          null: true, description: 'Custom roles available for the group.',
          resolver: ::Resolvers::MemberRoles::RolesResolver,
          authorize: :read_member_role,
          skip_type_authorization: :read_member_role,
          experiment: { milestone: '16.5' }

        field :standard_role, ::Types::Members::StandardRoleType,
          null: true, description: 'Finds a single default role for the group. Available only for SaaS.',
          resolver: ::Resolvers::Members::StandardRolesResolver.single,
          experiment: { milestone: '17.6' }

        field :standard_roles, ::Types::Members::StandardRoleType.connection_type,
          null: true, description: 'Default roles available for the group. Available only for SaaS.',
          resolver: ::Resolvers::Members::StandardRolesResolver,
          experiment: { milestone: '17.4' }

        field :pending_members,
          ::Types::Members::PendingMemberInterface.connection_type,
          null: true,
          description: 'A pending membership of a user within this group.',
          resolver: Resolvers::PendingGroupMembersResolver,
          experiment: { milestone: '16.6' }

        field :value_streams,
          description: 'Value streams available to the group.',
          null: true,
          resolver: ::Resolvers::Analytics::CycleAnalytics::ValueStreamsResolver,
          max_page_size: 20

        field :saved_replies,
          ::Types::Groups::SavedReplyType.connection_type,
          null: true,
          resolver: ::Resolvers::Groups::SavedRepliesResolver,
          description: 'Saved replies available to the group. This field can only be resolved ' \
                       'for one group in any single request.'

        field :saved_reply,
          resolver: ::Resolvers::Groups::SavedReplyResolver,
          description: 'Saved reply in the group. This field can only ' \
                       'be resolved for one group in any single request.'

        field :value_stream_analytics,
          ::Types::Analytics::ValueStreamAnalyticsType,
          description: 'Information about Value Stream Analytics within the group.',
          null: true,
          resolver_method: :object

        field :security_policy_project_suggestions,
          ::Types::ProjectType.connection_type,
          null: true,
          description: 'Security policy project suggestions',
          resolver: ::Resolvers::SecurityOrchestration::SecurityPolicyProjectSuggestionsResolver

        field :duo_features_enabled, GraphQL::Types::Boolean,
          experiment: { milestone: '16.10' },
          description: 'Indicates whether GitLab Duo features are enabled for the group.'

        field :lock_duo_features_enabled, GraphQL::Types::Boolean,
          experiment: { milestone: '16.10' },
          description: 'Indicates if the GitLab Duo features enabled setting is enforced for all subgroups.'

        field :pending_member_approvals,
          EE::Types::GitlabSubscriptions::MemberManagement::MemberApprovalType.connection_type,
          null: true,
          resolver: ::Resolvers::GitlabSubscriptions::MemberManagement::MemberApprovalResolver,
          description: 'Pending member promotions of the group.'

        field :dependencies, ::Types::Sbom::DependencyType.connection_type,
          null: true,
          resolver: ::Resolvers::Sbom::DependenciesResolver,
          description: 'Software dependencies used by projects under this group.'

        field :dependency_aggregations, ::Types::Sbom::DependencyAggregationType.connection_type,
          null: true,
          experiment: { milestone: '18.0' },
          authorize: :read_dependency,
          resolver: ::Resolvers::Sbom::DependencyAggregationResolver,
          description: 'Software dependencies used by projects under this group.'

        field :components,
          [::Types::Sbom::ComponentType],
          null: true,
          authorize: :read_dependency,
          description: 'Find software dependencies by name.',
          resolver: ::Resolvers::Sbom::ComponentResolver,
          experiment: { milestone: '17.5' }

        field :component_versions,
          ::Types::Sbom::ComponentVersionType.connection_type,
          null: false,
          authorize: :read_dependency,
          description: 'Find software dependency versions by component name.',
          resolver: ::Resolvers::Sbom::ComponentVersionResolver,
          experiment: { milestone: '18.0' }

        field :custom_fields, ::Types::Issuables::CustomFieldType.connection_type,
          null: true,
          description: 'Custom fields configured for the group.',
          resolver: ::Resolvers::Issuables::CustomFieldsResolver,
          experiment: { milestone: '17.5' }

        field :custom_field, ::Types::Issuables::CustomFieldType,
          null: true,
          description: 'A custom field configured for the group.',
          resolver: ::Resolvers::Issuables::CustomFieldResolver,
          experiment: { milestone: '17.6' }

        field :project_compliance_requirements_status,
          ::Types::ComplianceManagement::ComplianceFramework::ProjectRequirementStatusType.connection_type,
          null: true,
          description: 'Compliance statuses for the projects in a group and its subgroups.',
          resolver: ::Resolvers::ComplianceManagement::ComplianceFramework::GroupProjectRequirementStatusResolver,
          authorize: :read_compliance_adherence_report,
          experiment: { milestone: '17.10' }

        field :analyzer_statuses, [::Types::Security::AnalyzerGroupStatusType],
          null: true,
          description: 'Status for all analyzers in the group.',
          resolver: ::Resolvers::Security::AnalyzerGroupStatusResolver

        field :compliance_requirement_control_coverage,
          ::Types::ComplianceManagement::ComplianceFramework::RequirementControlCoverageType,
          null: true,
          description: 'Compliance control status summary showing count of passed, failed, and pending controls.',
          resolver: ::Resolvers::ComplianceManagement::ComplianceFramework::RequirementControlCoverageResolver,
          authorize: :read_compliance_dashboard,
          experiment: { milestone: '18.1' }

        field :compliance_frameworks_coverage_details,
          ::Types::ComplianceManagement::ComplianceFramework::FrameworkCoverageDetailType.connection_type,
          null: true,
          description: 'Detailed compliance framework coverage for each framework in the group.',
          resolver: ::Resolvers::ComplianceManagement::ComplianceFramework::FrameworkCoverageDetailsResolver,
          authorize: :read_compliance_dashboard,
          experiment: { milestone: '18.1' }

        field :maven_virtual_registries,
          EE::Types::VirtualRegistries::Packages::Maven::MavenVirtualRegistryType.connection_type,
          null: true,
          description: 'Maven virtual registries registered to the group. ' \
            'Returns null if the `maven_virtual_registry` feature flag is disabled.',
          experiment: { milestone: '18.1' }

        field :compliance_framework_coverage_summary,
          ::Types::ComplianceManagement::ComplianceFramework::FrameworkCoverageSummaryType,
          null: true,
          description: 'Summary of compliance framework coverage in a group and its subgroups.',
          resolver: ::Resolvers::ComplianceManagement::ComplianceFramework::FrameworkCoverageSummaryResolver,
          authorize: :read_compliance_dashboard,
          experiment: { milestone: '18.1' }

        field :security_metrics,
          ::Types::Security::SecurityMetricsType,
          null: true,
          description: 'Security metrics.' \
          'This feature is currently under development and not yet available for general use.',
          resolver: ::Resolvers::Security::SecurityMetricsResolver,
          experiment: { milestone: '18.2' }

        field :project_compliance_violations,
          ::Types::ComplianceManagement::Projects::ComplianceViolationType.connection_type,
          null: true,
          description: 'Compliance violations for the projects in a group and its subgroups.',
          resolver: ::Resolvers::ComplianceManagement::Projects::GroupViolationsResolver,
          authorize: :read_compliance_violations_report,
          experiment: { milestone: '18.1' }

        field :compliance_requirement_coverage,
          ::Types::ComplianceManagement::ComplianceFramework::RequirementCoverageType,
          null: true,
          description: 'Compliance requirement coverage statistics for the group.',
          resolver: ::Resolvers::ComplianceManagement::ComplianceFramework::RequirementCoverageResolver,
          authorize: :read_compliance_dashboard,
          experiment: { milestone: '18.2' }

        field :compliance_frameworks_needing_attention,
          ::Types::ComplianceManagement::ComplianceFramework::FrameworksNeedingAttentionType.connection_type,
          null: true,
          description: 'Frameworks missing either project assignments or requirements definitions.',
          resolver: ::Resolvers::ComplianceManagement::ComplianceFramework::FrameworksNeedingAttentionResolver,
          authorize: :read_compliance_dashboard,
          experiment: { milestone: '18.2' }

        field :web_based_commit_signing_enabled,
          GraphQL::Types::Boolean,
          null: false,
          description: 'Indicates whether web-based commit signing is enabled for the group.',
          experiment: { milestone: '18.2' }

        def epics_enabled
          object.licensed_feature_available?(:epics)
        end

        def billable_members_count(requested_hosted_plan: nil)
          object.billable_members_count(requested_hosted_plan)
        end

        def runner_cloud_provisioning(provider:, cloud_project_id:)
          {
            container: object,
            provider: provider,
            cloud_project_id: cloud_project_id
          }
        end

        def vulnerability_namespace_statistic
          return unless ::Feature.enabled?(:security_inventory_dashboard, object.root_ancestor)
          return unless object.licensed_feature_available?(:security_inventory)

          object.vulnerability_namespace_statistic
        end

        def analyzer_statuses
          BatchLoader::GraphQL.for(object).batch do |groups, loader|
            ::Namespaces::Preloaders::GroupRootAncestorPreloader.new(groups).execute if groups.present?

            groups.each do |group|
              unless ::Feature.enabled?(:security_inventory_dashboard, group.root_ancestor) &&
                  group.licensed_feature_available?(:security_inventory)
                next loader.call(group, nil)
              end

              loader.call(group, group.analyzer_group_statuses)
            end
          end
        end

        def maven_virtual_registries
          ::VirtualRegistries::Packages::Maven::Registry.for_group(object) if ::Feature.enabled?(
            :maven_virtual_registry, object)
        end
      end
    end
  end
end
