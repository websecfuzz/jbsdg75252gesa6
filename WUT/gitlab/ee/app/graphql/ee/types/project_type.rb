# frozen_string_literal: true

module EE
  module Types
    module ProjectType
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      prepended do
        field :security_scanners, ::Types::SecurityScanners,
          null: true,
          description: 'Information about security analyzers used in the project.',
          method: :itself

        field :security_training_providers, [::Types::Security::TrainingType],
          null: true,
          description: 'List of security training providers for the project',
          resolver: ::Resolvers::SecurityTrainingProvidersResolver

        field :vulnerability_archives, [::Types::Vulnerabilities::ArchiveType],
          null: true,
          description: 'All vulnerability archives of the project.',
          experiment: { milestone: '17.9' },
          resolver: ::Resolvers::Vulnerabilities::ArchivesResolver

        field :vulnerabilities, ::Types::VulnerabilityType.connection_type,
          null: true,
          extras: [:lookahead],
          description: 'Vulnerabilities reported on the project.',
          resolver: ::Resolvers::VulnerabilitiesResolver,
          scopes: [:api, :read_api, :ai_workflows]

        field :vulnerability_scanners, ::Types::VulnerabilityScannerType.connection_type,
          null: true,
          description: 'Vulnerability scanners reported on the project vulnerabilities.',
          resolver: ::Resolvers::Vulnerabilities::ScannersResolver

        field :vulnerabilities_count_by_day, ::Types::VulnerabilitiesCountByDayType.connection_type,
          null: true,
          description: 'The historical number of vulnerabilities per day for the project.',
          resolver: ::Resolvers::VulnerabilitiesCountPerDayResolver

        field :vulnerability_statistic, ::Types::Security::VulnerabilityStatisticType,
          null: true,
          description: 'Counts for each vulnerability severity in the project.',
          authorize: :read_vulnerability_statistics,
          skip_type_authorization: :read_vulnerability_statistics

        field :vulnerability_severities_count, ::Types::VulnerabilitySeveritiesCountType,
          null: true,
          description: 'Counts for each vulnerability severity in the project.',
          resolver: ::Resolvers::VulnerabilitySeveritiesCountResolver

        field :requirement, ::Types::RequirementsManagement::RequirementType,
          null: true,
          description: 'Find a single requirement.',
          resolver: ::Resolvers::RequirementsManagement::RequirementsResolver.single

        field :requirements, ::Types::RequirementsManagement::RequirementType.connection_type,
          null: true,
          description: 'Find requirements.',
          extras: [:lookahead],
          resolver: ::Resolvers::RequirementsManagement::RequirementsResolver

        field :requirement_states_count, ::Types::RequirementsManagement::RequirementStatesCountType,
          null: true,
          description: 'Number of requirements for the project by their state.'

        field :compliance_frameworks, ::Types::ComplianceManagement::ComplianceFrameworkType.connection_type,
          description: 'Compliance frameworks associated with the project.',
          null: true do
            argument :sort, ::Types::ComplianceManagement::ComplianceFrameworkSortEnum,
              required: false,
              description: 'Sort compliance frameworks by the criteria.'
          end

        field :merge_request_violations,
          ::Types::ComplianceManagement::MergeRequests::ComplianceViolationType.connection_type,
          null: true,
          description: 'Compliance violations reported on merge requests merged within the project.',
          resolver: ::Resolvers::ComplianceManagement::MergeRequests::ProjectComplianceViolationResolver,
          authorize: :read_compliance_violations_report

        field :compliance_standards_adherence,
          ::Types::Projects::ComplianceStandards::AdherenceType.connection_type,
          null: true,
          description: 'Compliance standards adherence for the project.',
          resolver: ::Resolvers::Projects::ComplianceStandards::ProjectAdherenceResolver,
          authorize: :read_compliance_adherence_report

        field :compliance_control_status,
          ::Types::ComplianceManagement::ComplianceFramework::ProjectControlStatusType.connection_type,
          null: true,
          description: 'Compliance control statuses for a project.',
          resolver: ::Resolvers::ComplianceManagement::ComplianceFramework::ProjectControlStatusResolver,
          authorize: :read_compliance_adherence_report,
          experiment: { milestone: '17.11' }

        field :compliance_requirement_statuses,
          ::Types::ComplianceManagement::ComplianceFramework::ProjectRequirementStatusType.connection_type,
          null: true,
          description: 'Compliance requirement statuses for a project.',
          resolver: ::Resolvers::ComplianceManagement::ComplianceFramework::ProjectRequirementStatusResolver,
          authorize: :read_compliance_adherence_report,
          experiment: { milestone: '18.0' }

        field :security_dashboard_path, GraphQL::Types::String,
          description: "Path to project's security dashboard.",
          null: true

        field :vulnerability_identifier_search,
          [GraphQL::Types::String],
          resolver: ::Resolvers::Vulnerabilities::IdentifierSearchResolver,
          null: true,
          description: 'Search for vulnerabilities by identifier.'

        field :iterations, ::Types::IterationType.connection_type,
          null: true,
          description: 'Find iterations.',
          resolver: ::Resolvers::IterationsResolver

        field :iteration_cadences, ::Types::Iterations::CadenceType.connection_type,
          null: true,
          description: 'Find iteration cadences.',
          resolver: ::Resolvers::Iterations::CadencesResolver

        field :dast_profile,
          ::Types::Dast::ProfileType,
          null: true,
          resolver: ::Resolvers::AppSec::Dast::ProfileResolver.single,
          calls_gitaly: true,
          description: 'DAST Profile associated with the project.'

        field :dast_profiles,
          ::Types::Dast::ProfileType.connection_type,
          null: true,
          extras: [:lookahead],
          late_extensions: [::Gitlab::Graphql::Project::DastProfileConnectionExtension],
          resolver: ::Resolvers::AppSec::Dast::ProfileResolver,
          calls_gitaly: true,
          description: 'DAST Profiles associated with the project.'

        field :dast_site_profile,
          ::Types::DastSiteProfileType,
          null: true,
          resolver: ::Resolvers::DastSiteProfileResolver.single,
          description: 'DAST Site Profile associated with the project.'

        field :dast_site_profiles,
          ::Types::DastSiteProfileType.connection_type,
          null: true,
          description: 'DAST Site Profiles associated with the project.',
          resolver: ::Resolvers::DastSiteProfileResolver

        field :dast_scanner_profiles,
          ::Types::DastScannerProfileType.connection_type,
          null: true,
          description: 'DAST scanner profiles associated with the project.'

        field :dast_site_validations,
          ::Types::DastSiteValidationType.connection_type,
          null: true,
          resolver: ::Resolvers::DastSiteValidationResolver,
          description: 'DAST Site Validations associated with the project.'

        field :repository_size_excess,
          GraphQL::Types::Float,
          null: true,
          description: 'Size of repository that exceeds the limit in bytes.'

        field :actual_repository_size_limit,
          GraphQL::Types::Float,
          null: true,
          description: 'Size limit for the repository in bytes.'

        field :code_coverage_summary,
          ::Types::Ci::CodeCoverageSummaryType,
          null: true,
          description: 'Code coverage summary associated with the project.',
          resolver: ::Resolvers::Ci::CodeCoverageSummaryResolver

        field :alert_management_payload_fields,
          [::Types::AlertManagement::PayloadAlertFieldType],
          null: true,
          description: 'Extract alert fields from payload for custom mapping.',
          resolver: ::Resolvers::AlertManagement::PayloadAlertFieldResolver

        field :incident_management_oncall_schedules,
          ::Types::IncidentManagement::OncallScheduleType.connection_type,
          null: true,
          description: 'Incident Management On-call schedules of the project.',
          extras: [:lookahead],
          resolver: ::Resolvers::IncidentManagement::OncallScheduleResolver

        field :incident_management_escalation_policies,
          ::Types::IncidentManagement::EscalationPolicyType.connection_type,
          null: true,
          description: 'Incident Management escalation policies of the project.',
          extras: [:lookahead],
          resolver: ::Resolvers::IncidentManagement::EscalationPoliciesResolver

        field :incident_management_escalation_policy,
          ::Types::IncidentManagement::EscalationPolicyType,
          null: true,
          description: 'Incident Management escalation policy of the project.',
          resolver: ::Resolvers::IncidentManagement::EscalationPoliciesResolver.single

        field :api_fuzzing_ci_configuration,
          ::Types::AppSec::Fuzzing::API::CiConfigurationType,
          null: true,
          description: 'API fuzzing configuration for the project. '

        field :corpuses, ::Types::AppSec::Fuzzing::Coverage::CorpusType.connection_type,
          null: true,
          resolver: ::Resolvers::AppSec::Fuzzing::Coverage::CorpusesResolver,
          description: "Find corpuses of the project."

        field :push_rules,
          ::Types::PushRulesType,
          null: true,
          description: "Project's push rules settings.",
          method: :push_rule

        field :path_locks,
          ::Types::PathLockType.connection_type,
          null: true,
          description: "The project's path locks.",
          extras: [:lookahead],
          resolver: ::Resolvers::PathLocksResolver

        field :security_policies,
          ::Types::SecurityOrchestration::SecurityPolicyType.connection_type,
          calls_gitaly: true,
          null: true,
          description: 'All security policies of the project.',
          resolver: ::Resolvers::SecurityOrchestration::SecurityPolicyResolver,
          experiment: { milestone: '18.1' }

        field :vulnerability_management_policies,
          ::Types::Security::VulnerabilityManagementPolicyType.connection_type,
          calls_gitaly: true,
          null: true,
          experiment: { milestone: '17.5' },
          description: 'Vulnerability Management Policies of the project.',
          resolver: ::Resolvers::Security::VulnerabilityManagementPolicyResolver

        field :pipeline_execution_policies,
          ::Types::SecurityOrchestration::PipelineExecutionPolicyType.connection_type,
          calls_gitaly: true,
          null: true,
          description: 'Pipeline Execution Policies of the project.',
          resolver: ::Resolvers::SecurityOrchestration::PipelineExecutionPolicyResolver

        field :pipeline_execution_schedule_policies,
          ::Types::SecurityOrchestration::PipelineExecutionSchedulePolicyType.connection_type,
          calls_gitaly: true,
          null: true,
          description: 'Pipeline Execution Schedule Policies of the namespace.',
          resolver: ::Resolvers::SecurityOrchestration::PipelineExecutionSchedulePolicyResolver

        field :scan_execution_policies,
          ::Types::SecurityOrchestration::ScanExecutionPolicyType.connection_type,
          calls_gitaly: true,
          null: true,
          description: 'Scan Execution Policies of the project',
          resolver: ::Resolvers::SecurityOrchestration::ScanExecutionPolicyResolver

        field :scan_result_policies,
          ::Types::SecurityOrchestration::ScanResultPolicyType.connection_type,
          calls_gitaly: true,
          null: true,
          deprecated: { reason: 'Use `approvalPolicies`', milestone: '16.9' },
          description: 'Scan Result Policies of the project',
          resolver: ::Resolvers::SecurityOrchestration::ScanResultPolicyResolver

        field :approval_policies,
          ::Types::SecurityOrchestration::ApprovalPolicyType.connection_type,
          calls_gitaly: true,
          null: true,
          description: 'Approval Policies of the project',
          resolver: ::Resolvers::SecurityOrchestration::ApprovalPolicyResolver

        field :security_policy_project,
          ::Types::ProjectType,
          null: true,
          method: :security_policy_management_project,
          description: 'Security policy project assigned to the project, absent if assigned to a parent group.'

        field :security_policy_project_linked_projects,
          ::Types::ProjectType.connection_type,
          null: true,
          description: 'Projects linked to the project, when used as Security Policy Project.'

        field :security_policy_project_linked_namespaces,
          ::Types::NamespaceType.connection_type,
          null: true,
          description: 'Namespaces linked to the project, when used as Security Policy Project.',
          deprecated: { reason: :renamed, replacement: 'security_policy_project_linked_groups', milestone: '17.4' }

        field :security_policy_project_linked_groups,
          ::Types::GroupType.connection_type,
          null: true,
          description: 'Groups linked to the project, when used as Security Policy Project.',
          resolver: ::Resolvers::Security::SecurityPolicyProjectLinkedGroupsResolver

        field :security_policy_project_suggestions,
          ::Types::ProjectType.connection_type,
          null: true,
          description: 'Security policy project suggestions',
          resolver: ::Resolvers::SecurityOrchestration::SecurityPolicyProjectSuggestionsResolver

        field :dora,
          ::Types::Analytics::Dora::DoraType,
          null: true,
          method: :itself,
          description: "Project's DORA metrics."

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

        field :security_training_urls,
          [::Types::Security::TrainingUrlType],
          null: true,
          description: 'Security training URLs for the enabled training providers of the project.',
          resolver: ::Resolvers::SecurityTrainingUrlsResolver

        field :vulnerability_images,
          type: ::Types::Vulnerabilities::ContainerImageType.connection_type,
          null: true,
          description: 'Container images reported on the project vulnerabilities.',
          resolver: ::Resolvers::Vulnerabilities::ContainerImagesResolver

        field :only_allow_merge_if_all_status_checks_passed, GraphQL::Types::Boolean,
          null: true,
          description: 'Indicates that merges of merge requests should be blocked ' \
                       'unless all status checks have passed.'

        field :duo_features_enabled, GraphQL::Types::Boolean,
          null: true,
          experiment: { milestone: '16.9' },
          description: 'Indicates whether GitLab Duo features are enabled for the project.'

        field :duo_context_exclusion_settings, ::Types::Projects::DuoContextExclusionSettingsType,
          null: true,
          description: 'Settings for excluding files from Duo context.',
          experiment: { milestone: '18.2' }

        field :duo_workflow_status_check, ::Types::Ai::DuoWorkflows::EnablementType,
          null: true,
          experiment: { milestone: '17.7' },
          description: 'Indicates whether Duo Agent Platform is enabled for the project.'

        field :gitlab_subscriptions_preview_billable_user_change,
          ::Types::GitlabSubscriptions::PreviewBillableUserChangeType,
          null: true,
          complexity: 100,
          description: 'Preview Billable User Changes',
          resolver: ::Resolvers::GitlabSubscriptions::PreviewBillableUserChangeResolver

        field :customizable_dashboards, ::Types::Analytics::Dashboards::DashboardType.connection_type,
          description: 'Customizable dashboards for the project.',
          null: true,
          calls_gitaly: true,
          experiment: { milestone: '15.6' },
          resolver: ::Resolvers::Analytics::Dashboards::DashboardsResolver

        field :customizable_dashboard_visualizations, ::Types::Analytics::Dashboards::VisualizationType.connection_type,
          description: 'Visualizations of the project or associated configuration project.',
          null: true,
          calls_gitaly: true,
          experiment: { milestone: '16.1' },
          resolver: ::Resolvers::Analytics::Dashboards::VisualizationsResolver

        field :product_analytics_state, ::Types::ProductAnalytics::StateEnum,
          description: 'Current state of the product analytics stack for this project.' \
                       'Can only be called for one project in a single request',
          null: true,
          experiment: { milestone: '15.10' },
          resolver: ::Resolvers::ProductAnalytics::StateResolver do
          extension ::Gitlab::Graphql::Limit::FieldCallCount, limit: 1
        end

        field :product_analytics_settings,
          description: 'Project-level settings for product analytics.',
          null: true,
          resolver: ::Resolvers::Analytics::ProductAnalytics::ProjectSettingsResolver

        field :tracking_key, GraphQL::Types::String,
          null: true,
          description: 'Tracking key assigned to the project.',
          experiment: { milestone: '16.0' },
          authorize: :developer_access

        field :product_analytics_instrumentation_key, GraphQL::Types::String,
          null: true,
          description: 'Product Analytics instrumentation key assigned to the project.',
          experiment: { milestone: '16.0' },
          authorize: :developer_access

        field :dependencies, ::Types::Sbom::DependencyType.connection_type,
          null: true,
          description: 'Software dependencies used by the project.',
          resolver: ::Resolvers::Sbom::DependenciesResolver

        field :dependency_paths,
          ::Types::Sbom::DependencyPathPage,
          null: true,
          authorize: :read_dependency,
          description: 'Ancestor dependency paths for a dependency used by the project. \
          Returns `null` if `dependency_graph_graphql` feature flag is disabled.',
          resolver: ::Resolvers::Sbom::DependencyPathsResolver,
          experiment: { milestone: '17.10' }

        field :components,
          [::Types::Sbom::ComponentType],
          null: true,
          authorize: :read_dependency,
          description: 'Find software dependencies by name.',
          resolver: ::Resolvers::Sbom::ComponentResolver,
          experiment: { milestone: '17.9' }

        field :component_versions,
          ::Types::Sbom::ComponentVersionType.connection_type,
          null: false,
          authorize: :read_dependency,
          description: 'Find software dependency versions by component name.',
          resolver: ::Resolvers::Sbom::ComponentVersionResolver,
          experiment: { milestone: '17.10' }

        field :merge_requests_disable_committers_approval, GraphQL::Types::Boolean,
          null: false,
          description: 'Indicates that committers of the given merge request cannot approve.'

        field :has_jira_vulnerability_issue_creation_enabled, GraphQL::Types::Boolean,
          null: false,
          method: :configured_to_create_issues_from_vulnerabilities?,
          description: 'Indicates whether Jira issue creation from vulnerabilities is enabled.'

        field :pre_receive_secret_detection_enabled, GraphQL::Types::Boolean,
          null: true,
          description: 'Indicates whether Secret Push Protection is on or not for the project.',
          method: :secret_push_protection_enabled,
          authorize: :read_secret_push_protection_info

        field :secret_push_protection_enabled, GraphQL::Types::Boolean,
          null: true,
          description: 'Indicates whether Secret Push Protection is on or not for the project.',
          authorize: :read_secret_push_protection_info

        field :container_scanning_for_registry_enabled, GraphQL::Types::Boolean,
          null: true,
          description: 'Indicates whether Container Scanning for Registry is enabled or not for the project. ' \
            'Returns `null` if unauthorized.',
          authorize: :read_security_configuration

        field :prevent_merge_without_jira_issue_enabled, GraphQL::Types::Boolean,
          null: false,
          method: :prevent_merge_without_jira_issue?,
          description: 'Indicates if an associated issue from Jira is required.'

        field :product_analytics_events_stored, [::Types::ProductAnalytics::MonthlyUsageType],
          null: true,
          resolver: ::Resolvers::ProductAnalytics::ProjectUsageDataResolver,
          description: 'Count of all events used, broken down by month',
          experiment: { milestone: '16.7' }

        field :dependency_proxy_packages_setting,
          ::Types::DependencyProxy::Packages::SettingType,
          null: true,
          description: 'Packages Dependency Proxy settings for the project. ' \
                       'Requires the packages and dependency proxy to be enabled in the config. ' \
                       'Requires the packages feature to be enabled at the project level. '
        field :member_roles, ::Types::MemberRoles::MemberRoleType.connection_type,
          null: true, description: 'Member roles available for the group.',
          resolver: ::Resolvers::MemberRoles::RolesResolver,
          authorize: :read_member_role,
          skip_type_authorization: :read_member_role,
          experiment: { milestone: '16.5' }

        field :ci_subscriptions_projects,
          type: ::Types::Ci::Subscriptions::ProjectType.connection_type,
          deprecated: { reason: 'Use `ciUpstreamProjectSubscriptions`', milestone: '17.6' },
          method: :upstream_project_subscriptions,
          description: 'Pipeline subscriptions for the project.'

        field :ci_upstream_project_subscriptions,
          type: ::Types::Ci::ProjectSubscriptionType.connection_type,
          method: :upstream_project_subscriptions,
          description: 'Pipeline subscriptions where this project is the downstream project.' \
                       'When an upstream project\'s pipeline completes, a pipeline is triggered ' \
                       'in the downstream project (this project).',
          experiment: { milestone: '17.6' }

        field :ci_subscribed_projects,
          type: ::Types::Ci::Subscriptions::ProjectType.connection_type,
          deprecated: { reason: 'Use `ciDownstreamProjectSubscriptions`', milestone: '17.6' },
          method: :downstream_project_subscriptions,
          description: 'Pipeline subscriptions for projects subscribed to the project.'

        field :ci_downstream_project_subscriptions,
          type: ::Types::Ci::ProjectSubscriptionType.connection_type,
          method: :downstream_project_subscriptions,
          description: 'Pipeline subscriptions where this project is the upstream project.' \
                       'When this project\'s pipeline completes, a pipeline is triggered ' \
                       'in the downstream project.',
          experiment: { milestone: '17.6' }

        field :runner_cloud_provisioning,
          ::Types::Ci::RunnerCloudProvisioningType,
          null: true,
          experiment: { milestone: '16.9' },
          description: 'Information used for provisioning the runner on a cloud provider. ' \
                       'Returns `null` if the GitLab instance is not a SaaS instance.' do
                         argument :provider, ::Types::Ci::RunnerCloudProviderEnum, required: true,
                           description: 'Identifier of the cloud provider.'
                         argument :cloud_project_id, ::Types::GoogleCloud::ProjectType, required: true,
                           description: 'Identifier of the cloud project.'
                       end

        field :ai_agents, ::Types::Ai::Agents::AgentType.connection_type,
          null: true,
          experiment: { milestone: '16.9' },
          description: 'Ai Agents for the project.',
          resolver: ::Resolvers::Ai::Agents::FindAgentResolver

        field :google_cloud_artifact_registry_repository,
          ::Types::GoogleCloud::ArtifactRegistry::RepositoryType,
          null: true,
          experiment: { milestone: '16.10' },
          description: 'Google Artifact Registry repository. ' \
                       'Returns `null` if the GitLab instance is not a SaaS instance.'

        field :ai_agent, ::Types::Ai::Agents::AgentType,
          null: true,
          experiment: { milestone: '16.10' },
          description: 'Find a specific AI Agent.',
          resolver: ::Resolvers::Ai::Agents::AgentDetailResolver

        field :ai_xray_reports, ::Types::Ai::XrayReportType.connection_type,
          null: false,
          experiment: { milestone: '17.8' },
          description: 'X-ray reports of the project.',
          method: :xray_reports

        field :value_stream_analytics,
          ::Types::Analytics::ValueStreamAnalyticsType,
          description: 'Information about Value Stream Analytics within the project.',
          null: true,
          resolver_method: :object

        field :value_stream_dashboard_usage_overview,
          ::Types::Analytics::ValueStreamDashboard::CountType,
          null: true,
          resolver: ::Resolvers::Projects::Analytics::ValueStreamDashboard::CountResolver,
          description: 'Aggregated usage counts within the project',
          experiment: { milestone: '17.2' }

        field :saved_replies,
          ::Types::Projects::SavedReplyType.connection_type,
          null: true,
          description: 'Saved replies available to the project.'

        field :saved_reply,
          resolver: ::Resolvers::Projects::SavedReplyResolver,
          description: 'Saved reply in the project.'

        field :merge_trains,
          ::Types::MergeTrains::TrainType.connection_type,
          resolver: ::Resolvers::MergeTrains::TrainsResolver,
          description: 'Merge trains available to the project. ',
          experiment: { milestone: '17.1' }

        field :pending_member_approvals,
          EE::Types::GitlabSubscriptions::MemberManagement::MemberApprovalType.connection_type,
          null: true,
          resolver: ::Resolvers::GitlabSubscriptions::MemberManagement::MemberApprovalResolver,
          description: 'Pending member promotions of the project.'

        field :observability_logs_links,
          ::Types::Observability::LogType.connection_type,
          null: true,
          experiment: { milestone: '17.4' },
          description: 'Logs attached to the project.',
          resolver: ::Resolvers::Observability::LogsResolver

        field :observability_metrics_links,
          ::Types::Observability::MetricType.connection_type,
          null: true,
          experiment: { milestone: '17.4' },
          description: 'Metrics attached to the project.',
          resolver: ::Resolvers::Observability::MetricsResolver

        field :observability_traces_links,
          ::Types::Observability::TraceType.connection_type,
          null: true,
          experiment: { milestone: '17.4' },
          description: 'Traces attached to the project.',
          resolver: ::Resolvers::Observability::TracesResolver

        field :component_usages, ::Types::Ci::Catalog::Resources::Components::UsageType.connection_type,
          null: true,
          description: 'Component(s) used by the project.',
          resolver: ::Resolvers::Ci::Catalog::Resources::Components::ProjectUsageResolver

        field :security_exclusions,
          ::Types::Security::ProjectSecurityExclusionType.connection_type,
          null: true,
          experiment: { milestone: '17.4' },
          description: 'Security exclusions of the project.',
          resolver: ::Resolvers::Security::ProjectSecurityExclusionResolver

        field :security_exclusion,
          ::Types::Security::ProjectSecurityExclusionType,
          null: true,
          experiment: { milestone: '17.4' },
          description: 'A single security exclusion of a project.',
          resolver: ::Resolvers::Security::ProjectSecurityExclusionResolver.single

        field :target_branch_rules, ::Types::Projects::TargetBranchRuleType.connection_type,
          null: true,
          description: 'Target branch rules of the project.'

        field :analyzer_statuses, [::Types::Security::AnalyzerProjectStatusType],
          null: true,
          description: 'Status for all analyzers in the project.'

        field :duo_agentic_chat_available, ::GraphQL::Types::Boolean,
          null: true,
          resolver: ::Resolvers::Ai::ProjectAgenticChatAccessResolver,
          experiment: { milestone: '18.1' },
          description: 'User access to Duo agentic Chat feature.'
      end

      def tracking_key
        return unless object.product_analytics_enabled?

        object.project_setting.product_analytics_instrumentation_key
      end

      def secret_push_protection_enabled
        object.security_setting.secret_push_protection_enabled
      end

      def api_fuzzing_ci_configuration
        return unless Ability.allowed?(current_user, :read_security_resource, object)

        configuration = ::AppSec::Fuzzing::API::CiConfiguration.new(project: object)

        {
          scan_modes: ::AppSec::Fuzzing::API::CiConfiguration::SCAN_MODES,
          scan_profiles: configuration.scan_profiles
        }
      end

      def dast_scanner_profiles
        DastScannerProfilesFinder.new(project_ids: [object.id]).execute
      end

      def requirement_states_count
        return unless Ability.allowed?(current_user, :read_requirement, object)

        object.requirements.counts_by_state
      end

      def security_dashboard_path
        Rails.application.routes.url_helpers.project_security_dashboard_index_path(object)
      end

      def compliance_frameworks(sort: nil)
        BatchLoader::GraphQL.for(object.id).batch(default_value: []) do |project_ids, loader|
          results = ::ComplianceManagement::Framework.with_projects(project_ids).sort_by_attribute(sort)

          results.each do |framework|
            framework.project_ids.each do |project_id|
              loader.call(project_id) { |xs| xs << framework }
            end
          end
        end
      end

      def runner_cloud_provisioning(provider:, cloud_project_id:)
        {
          container: project,
          provider: provider,
          cloud_project_id: cloud_project_id
        }
      end

      def google_cloud_artifact_registry_repository
        return unless ::Gitlab::Saas.feature_available?(:google_cloud_support)

        project
      end

      def duo_workflow_status_check
        ::Ai::DuoWorkflows::EnablementCheckService.new(project: object, current_user: current_user).execute
      end

      def vulnerability_statistic
        return unless ::Feature.enabled?(:security_inventory_dashboard, object.group&.root_ancestor)
        return unless object.licensed_feature_available?(:security_inventory)

        object.vulnerability_statistic
      end

      def analyzer_statuses
        BatchLoader::GraphQL.for(object).batch do |projects, loader|
          namespaces = projects.map(&:project_namespace).uniq

          ::Namespaces::Preloaders::NamespaceRootAncestorPreloader.new(namespaces).execute if namespaces.present?

          projects.each do |project|
            unless ::Feature.enabled?(:security_inventory_dashboard, project.root_ancestor) &&
                project.licensed_feature_available?(:security_inventory)
              next loader.call(project, nil)
            end

            loader.call(project, project.analyzer_statuses)
          end
        end
      end

      override :container_protection_tag_rules
      def container_protection_tag_rules
        return super unless object.licensed_feature_available?(:container_registry_immutable_tag_rules)

        # mutable tag rules come first before immutable
        super + object.container_registry_protection_tag_rules.immutable
      end
    end
  end
end
