# frozen_string_literal: true

module EE
  module API
    module Entities
      module Project
        extend ActiveSupport::Concern

        class_methods do
          extend ::Gitlab::Utils::Override

          override :preload_relation
          def preload_relation(projects_relation, options = {})
            super(projects_relation).with_compliance_management_frameworks.with_group_saml_provider.with_invited_groups.with_security_setting
          end
        end

        prepended do
          expose :approvals_before_merge, if: ->(project, _) { project.feature_available?(:merge_request_approvers) }
          expose :mirror, if: ->(project, _) { project.feature_available?(:repository_mirrors) }
          expose :mirror_user_id, if: ->(project, _) { project.mirror? }
          expose :mirror_trigger_builds, if: ->(project, _) { project.mirror? }
          expose :only_mirror_protected_branches, if: ->(project, _) { project.mirror? }
          expose :mirror_overwrites_diverged_branches, if: ->(project, _) { project.mirror? }
          expose :external_authorization_classification_label,
            if: ->(_, _) { License.feature_available?(:external_authorization_service_api_management) }
          # Expose old field names with the new permissions methods to keep API compatible
          # TODO: remove in API v5, replaced by *_access_level
          expose :requirements_enabled do |project, options|
            project.feature_available?(:requirements, options[:current_user])
          end
          expose(:requirements_access_level) { |project, _| project_feature_string_access_level(project, :requirements) }

          expose :security_and_compliance_enabled do |project, options|
            project.feature_available?(:security_and_compliance, options[:current_user])
          end
          expose :secret_push_protection_enabled, documentation: { type: 'boolean' }, if: ->(project, options) { Ability.allowed?(options[:current_user], :read_secret_push_protection_info, project) } do |project|
            project.security_setting&.secret_push_protection_enabled
          end
          expose :secret_push_protection_enabled,
            as: :pre_receive_secret_detection_enabled,
            documentation: { type: 'boolean' },
            if: ->(project, options) { Ability.allowed?(options[:current_user], :read_secret_push_protection_info, project) } do |project|
            project.security_setting&.secret_push_protection_enabled
          end
          expose :compliance_frameworks do |project, _|
            project.compliance_management_frameworks_names
          end
          expose :issues_template, if: ->(project, options) do
            project.feature_available?(:issuable_default_templates) &&
              Ability.allowed?(options[:current_user], :read_issue, project)
          end
          expose :merge_requests_template, if: ->(project, options) do
            project.feature_available?(:issuable_default_templates) &&
              Ability.allowed?(options[:current_user], :read_merge_request, project)
          end
          expose :restrict_pipeline_cancellation_role, as: :ci_restrict_pipeline_cancellation_role, if: ->(project, options) {
            project.ci_cancellation_restriction.feature_available? &&
              Ability.allowed?(options[:current_user], :admin_project, project)
          }
          expose :merge_pipelines_enabled?, as: :merge_pipelines_enabled, if: ->(project, _) { project.feature_available?(:merge_pipelines) }
          expose :merge_trains_enabled?, as: :merge_trains_enabled, if: ->(project, _) { project.feature_available?(:merge_pipelines) }
          expose :merge_trains_skip_train_allowed?, as: :merge_trains_skip_train_allowed, if: ->(project, _) { project.feature_available?(:merge_pipelines) }
          expose :only_allow_merge_if_all_status_checks_passed, if: ->(project, _) { project.feature_available?(:external_status_checks) }
          expose :allow_pipeline_trigger_approve_deployment, documentation: { type: 'boolean' }, if: ->(project, _) { project.feature_available?(:protected_environments) }
          expose :prevent_merge_without_jira_issue, if: ->(project, _) { project.feature_available?(:jira_issue_association_enforcement) }
          expose :auto_duo_code_review_enabled, if: ->(project, _) { project.namespace.has_active_add_on_purchase?(:duo_enterprise) }
          expose :web_based_commit_signing_enabled, if: ->(project, options) do
            ::Gitlab::Saas.feature_available?(:repositories_web_based_commit_signing) &&
              Ability.allowed?(options[:current_user], :admin_project, project)
          end
          expose :spp_repository_pipeline_access,
            documentation: { type: 'boolean', desc: 'The spp_repository_pipeline_access setting is only visible if the security_orchestration_policies feature is available.' },
            if: ->(project, _) { project.feature_available?(:security_orchestration_policies) }
        end
      end
    end
  end
end
