# frozen_string_literal: true

# NOTE:
# Implementing metrics direct in `usage_data.rb` is deprecated,
# please add new instrumentation class and use add_metric method.
# For more information, see https://docs.gitlab.com/ee/development/service_ping/metrics_instrumentation.html

module EE
  module Gitlab
    module UsageData
      extend ActiveSupport::Concern

      EE_MEMOIZED_VALUES = %i[
        approval_merge_request_rule_minimum_id
        approval_merge_request_rule_maximum_id
        merge_request_minimum_id
        merge_request_maximum_id
      ].freeze

      class_methods do
        extend ::Gitlab::Utils::Override

        override :data
        def data
          with_finished_at(:recording_ee_finished_at) do
            super
          end
        end

        override :features_usage_data
        def features_usage_data
          super.merge(features_usage_data_ee)
        end

        def features_usage_data_ee
          {
            elasticsearch_enabled: alt_usage_data(fallback: nil) { ::Gitlab::CurrentSettings.elasticsearch_search? },
            license_trial_ends_on: add_metric("LicenseMetric", options: { attribute: "trial_ends_on" }),
            geo_enabled: alt_usage_data(fallback: nil) { ::Gitlab::Geo.enabled? },
            user_cap_feature_enabled: add_metric('UserCapSettingEnabledMetric', time_frame: 'none')
          }
        end

        override :components_usage_data
        def components_usage_data
          usage_data = super

          usage_data[:advanced_search] = {
            distribution: add_metric("AdvancedSearch::DistributionMetric"),
            version: add_metric("AdvancedSearch::VersionMetric"),
            build_type: add_metric("AdvancedSearch::BuildTypeMetric"),
            lucene_version: add_metric("AdvancedSearch::LuceneVersionMetric")
          }

          usage_data
        end

        def requirements_counts
          return {} unless ::License.feature_available?(:requirements)

          {
            requirements_created: count(RequirementsManagement::Requirement),
            requirement_test_reports_manual: count(RequirementsManagement::TestReport.without_build),
            requirement_test_reports_ci: count(RequirementsManagement::TestReport.with_build),
            requirements_with_test_report: distinct_count(RequirementsManagement::TestReport, :issue_id)
          }
        end

        def approval_rules_counts
          {
            approval_project_rules: count(ApprovalProjectRule),
            approval_project_rules_with_target_branch: count(ApprovalProjectRulesProtectedBranch, :approval_project_rule_id),
            approval_project_rules_with_more_approvers_than_required: add_metric('ApprovalProjectRulesWithUserMetric', options: { count_type: 'more_approvers_than_required' }),
            approval_project_rules_with_less_approvers_than_required: add_metric('ApprovalProjectRulesWithUserMetric', options: { count_type: 'less_approvers_than_required' }),
            approval_project_rules_with_exact_required_approvers: add_metric('ApprovalProjectRulesWithUserMetric', options: { count_type: 'exact_required_approvers' })
          }
        end

        def on_demand_pipelines_usage
          { dast_on_demand_pipelines: count(::Ci::Pipeline.ondemand_dast_scan) }
        end

        # Note: when adding a preference, check if it's mapped to an attribute of a User model. If so, name
        # the base key part after a corresponding User model attribute, use its possible values as suffix values.
        override :user_preferences_usage
        def user_preferences_usage
          super.tap do |user_prefs_usage|
            user_prefs_usage.merge!(
              user_preferences_group_overview_details: count(::User.active.group_view_details)
            )
          end
        end

        def operations_dashboard_usage
          users_with_ops_dashboard_as_default = count(::User.active.with_dashboard('operations'))
          users_with_projects_added = distinct_count(UsersOpsDashboardProject.joins(:user).merge(::User.active), :user_id) # rubocop:disable CodeReuse/ActiveRecord

          {
            operations_dashboard_default_dashboard: users_with_ops_dashboard_as_default,
            operations_dashboard_users_with_projects_added: users_with_projects_added
          }
        end

        override :system_usage_data
        # Rubocop's Metrics/AbcSize metric is disabled for this method as Rubocop
        # determines this method to be too complex while there's no way to make it
        # less "complex" without introducing extra methods (which actually will
        # make things _more_ complex).
        #
        def system_usage_data
          super.tap do |usage_data|
            usage_data[:counts].merge!(
              {
                confidential_epics: count(::Epic.confidential),
                epics: count(::Epic),
                epic_issues: count(::EpicIssue),
                geo_nodes: count(::GeoNode),
                geo_event_log_max_id: alt_usage_data { maximum_id(Geo::EventLog) || 0 },
                ldap_group_links: count(::LdapGroupLink),
                issues_with_health_status: count(::Issue.with_any_health_status, start: minimum_id(::Issue), finish: maximum_id(::Issue)),
                ldap_keys: count(::LDAPKey),
                ldap_users: count(::User.ldap, 'users.id'),
                merged_merge_requests_using_approval_rules: count(::MergeRequest.merged.joins(:approval_rules), # rubocop: disable CodeReuse/ActiveRecord
                  start: minimum_id(::MergeRequest),
                  finish: maximum_id(::MergeRequest)),
                projects_mirrored_with_pipelines_enabled: count(::Project.mirrored_with_enabled_pipelines),
                projects_reporting_ci_cd_back_to_github: count(::Integrations::Github.active),
                status_page_projects: count(::StatusPage::ProjectSetting.enabled),
                status_page_issues: count(::Issue.on_status_page, start: minimum_id(::Issue), finish: maximum_id(::Issue)),
                template_repositories: add(count(::Project.with_repos_templates), count(::Project.with_groups_level_repos_templates))
              },
              requirements_counts,
              on_demand_pipelines_usage,
              operations_dashboard_usage)
          end
        end
        # Omitted because no user, creator or author associated: `lfs_objects`, `pool_repositories`, `web_hooks`
        override :usage_activity_by_stage_create
        # rubocop:disable CodeReuse/ActiveRecord
        def usage_activity_by_stage_create(time_period)
          super.merge({
            projects_enforcing_code_owner_approval: distinct_count(::Project.requiring_code_owner_approval.where(time_period), :creator_id),
            projects_with_sectional_code_owner_rules: projects_with_sectional_code_owner_rules(time_period),
            merge_requests_with_added_rules: distinct_count(::ApprovalMergeRequestRule.where(time_period).with_added_approval_rules,
              :merge_request_id,
              start: minimum_id(::ApprovalMergeRequestRule, :merge_request_id),
              finish: maximum_id(::ApprovalMergeRequestRule, :merge_request_id)),
            merge_requests_with_optional_codeowners: distinct_count(::ApprovalMergeRequestRule.code_owner_approval_optional.where(time_period), :merge_request_id),
            merge_requests_with_overridden_project_rules: merge_requests_with_overridden_project_rules(time_period),
            merge_requests_with_required_codeowners: distinct_count(::ApprovalMergeRequestRule.code_owner_approval_required.where(time_period), :merge_request_id),
            projects_imported_from_github: distinct_count(::Project.github_imported.where(time_period), :creator_id),
            projects_with_repositories_enabled: distinct_count(::Project.with_repositories_enabled.where(time_period),
              :creator_id,
              start: minimum_id(::User),
              finish: maximum_id(::User)),
            protected_branches: distinct_count(::Project.with_protected_branches.where(time_period),
              :creator_id,
              start: minimum_id(::User),
              finish: maximum_id(::User)),
            users_using_path_locks: distinct_count(PathLock.where(time_period), :user_id),
            users_using_lfs_locks: distinct_count(LfsFileLock.where(time_period), :user_id),
            total_number_of_path_locks: count(::PathLock.where(time_period)),
            total_number_of_locked_files: count(::LfsFileLock.where(time_period))
          }, approval_rules_counts)
        end
        # rubocop:enable CodeReuse/ActiveRecord

        override :usage_activity_by_stage_enablement
        # rubocop:disable CodeReuse/ActiveRecord
        def usage_activity_by_stage_enablement(time_period)
          return super unless ::Gitlab::Geo.enabled?

          super.merge({
            geo_secondary_web_oauth_users: distinct_count(
              OauthAccessGrant
                  .where(time_period)
                  .where(
                    application_id: GeoNode.secondary_nodes.select(:oauth_application_id)
                  ),
              :resource_owner_id
            ),
            # rubocop: disable UsageData/LargeTable
            # These fields are pre-calculated on the secondary for transmission and storage on the primary.
            # This will end up as an array of hashes with the data from GeoNodeStatus, see
            # https://docs.gitlab.com/ee/api/geo_nodes.html#retrieve-status-about-a-specific-geo-node for what
            # that inner hash may contain
            # For Example:
            # geo_node_usage: [
            #   {
            #     repositories_count: 10,
            #     ... other geo node status fields
            #   }
            # ]
            geo_node_usage: GeoNodeStatus.for_active_secondaries.map do |node|
                              GeoNodeStatus::RESOURCE_STATUS_FIELDS.index_with { |field| node[field] }
                            end
            # rubocop: enable UsageData/LargeTable
          })
        end
        # rubocop:enable CodeReuse/ActiveRecord

        # Omitted because no user, creator or author associated: `campaigns_imported_from_github`, `ldap_group_links`
        override :usage_activity_by_stage_manage
        # rubocop:disable CodeReuse/ActiveRecord
        def usage_activity_by_stage_manage(time_period)
          time_frame = metric_time_period(time_period)
          super.merge({
            ldap_keys: distinct_count(::LDAPKey.where(time_period), :user_id),
            ldap_users: distinct_count(::GroupMember.of_ldap_type.where(time_period), :user_id),
            value_stream_management_customized_group_stages: count(::Analytics::CycleAnalytics::Stage.where(custom: true)),
            projects_with_compliance_framework: count(::ComplianceManagement::ComplianceFramework::ProjectSettings),
            compliance_frameworks_with_pipeline: count(::ComplianceManagement::Framework.where.not(pipeline_configuration_full_path: nil).where(time_period)),
            ldap_servers: ldap_available_servers.size,
            ldap_group_sync_enabled: ldap_config_present_for_any_provider?(:group_base),
            ldap_admin_sync_enabled: ldap_config_present_for_any_provider?(:admin_group),
            group_saml_enabled: omniauth_provider_names.include?('group_saml'),
            audit_event_destinations: add_metric('CountEventStreamingDestinationsMetric', time_frame: time_frame)
          })
        end
        # rubocop:enable CodeReuse/ActiveRecord

        # rubocop:disable CodeReuse/ActiveRecord
        override :usage_activity_by_stage_monitor
        def usage_activity_by_stage_monitor(time_period)
          data = super.merge({
            operations_dashboard_users_with_projects_added: distinct_count(UsersOpsDashboardProject.joins(:user).merge(::User.active).where(time_period), :user_id)
          })

          if time_period.blank?
            data[:projects_incident_sla_enabled] = count(
              ::IncidentManagement::ProjectIncidentManagementSetting.where(sla_timer: true), :project_id)
          end

          data
        end
        # rubocop:enable CodeReuse/ActiveRecord

        # Omitted because no user, creator or author associated: `boards`, `labels`, `milestones`, `uploads`
        # Omitted because too expensive: `epics_deepest_relationship_level`
        override :usage_activity_by_stage_plan
        # rubocop:disable CodeReuse/ActiveRecord
        def usage_activity_by_stage_plan(time_period)
          super.merge({
            assignee_lists: distinct_count(::List.assignee.where(time_period), :user_id),
            epics: distinct_count(::Epic.where(time_period), :author_id),
            label_lists: distinct_count(::List.label.where(time_period), :user_id),
            milestone_lists: distinct_count(::List.milestone.where(time_period), :user_id)
          })
        end
        # rubocop:enable CodeReuse/ActiveRecord

        # Omitted because no user, creator or author associated: `environments`, `feature_flags`, `in_review_folder`, `pages_domains`
        override :usage_activity_by_stage_release
        # rubocop:disable CodeReuse/ActiveRecord
        def usage_activity_by_stage_release(time_period)
          time_frame = metric_time_period(time_period)
          super.merge({
            projects_mirrored_with_pipelines_enabled: distinct_count(::Project.mirrored_with_enabled_pipelines.where(time_period), :creator_id),
            releases_with_group_milestones: add_metric('CountUsersAssociatingGroupMilestonesToReleasesMetric', time_frame: time_frame)
          })
        end
        # rubocop:enable CodeReuse/ActiveRecord

        # Omitted because no user, creator or author associated: `ci_runners`
        # rubocop:disable CodeReuse/ActiveRecord
        override :usage_activity_by_stage_verify
        def usage_activity_by_stage_verify(time_period)
          super.merge({
            projects_reporting_ci_cd_back_to_github: distinct_count(::Project.with_github_integration_pipeline_events.where(time_period), :creator_id)
          })
        end
        # rubocop:enable CodeReuse/ActiveRecord

        private

        def to_date_arel_node(column)
          locked_timezone = Arel::Nodes::NamedFunction.new('TIMEZONE', [Arel.sql("'UTC'"), column])
          Arel::Nodes::NamedFunction.new('DATE', [locked_timezone])
        end

        def ldap_config_present_for_any_provider?(configuration_item)
          ldap_available_servers.any? { |server_config| server_config[configuration_item.to_s] }
        end

        def ldap_available_servers
          ::Gitlab::Auth::Ldap::Config.available_servers
        end

        # rubocop:disable CodeReuse/ActiveRecord
        def merge_requests_with_overridden_project_rules(time_period = nil)
          sql =
            <<~SQL
              (EXISTS (
                SELECT
                  1
                FROM
                  approval_merge_request_rule_sources
                WHERE
                  approval_merge_request_rule_sources.approval_merge_request_rule_id = approval_merge_request_rules.id
                  AND NOT EXISTS (
                    SELECT
                      1
                    FROM
                      approval_project_rules
                    WHERE
                      approval_project_rules.id = approval_merge_request_rule_sources.approval_project_rule_id
                      AND EXISTS (
                        SELECT
                          1
                        FROM
                          projects
                        WHERE
                          projects.id = approval_project_rules.project_id
                          AND projects.disable_overriding_approvers_per_merge_request = FALSE))))
                  OR("approval_merge_request_rules"."modified_from_project_rule" = TRUE)
            SQL

          distinct_count(
            ::ApprovalMergeRequestRule.where(time_period).where(sql),
            :merge_request_id,
            start: minimum_id(::ApprovalMergeRequestRule, :merge_request_id),
            finish: maximum_id(::ApprovalMergeRequestRule, :merge_request_id)
          )
        end
        # rubocop:enable CodeReuse/ActiveRecord

        # rubocop:disable CodeReuse/ActiveRecord
        def projects_with_sectional_code_owner_rules(time_period)
          distinct_count(
            ::ApprovalMergeRequestRule
              .code_owner
              .joins(:merge_request)
              .where.not(section: ::Gitlab::CodeOwners::Section::DEFAULT)
              .where(time_period),
            'merge_requests.target_project_id',
            start: minimum_id(::Project),
            finish: maximum_id(::Project)
          )
        end
        # rubocop:enable CodeReuse/ActiveRecord

        override :clear_memoized
        def clear_memoized
          super

          EE_MEMOIZED_VALUES.each { |v| clear_memoization(v) }
        end
      end
    end
  end
end
