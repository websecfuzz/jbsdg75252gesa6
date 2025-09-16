# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class ValidatePolicyService < ::BaseContainerService
      include ::Gitlab::Utils::StrongMemoize
      include Security::SecurityOrchestrationPolicies::CadenceChecker

      ValidationError = Struct.new(:field, :level, :message, :title, :index)

      DEFAULT_VALIDATION_ERROR_FIELD = :base

      # rubocop:disable Metrics/CyclomaticComplexity -- flat branching
      # rubocop:disable Metrics/PerceivedComplexity -- policy validation
      # rubocop:disable Metrics/AbcSize -- policy validation
      def execute
        return error_with_title(s_('SecurityOrchestration|Empty policy name')) if blank_name?

        return success if policy_disabled?

        return error_with_title(s_('SecurityOrchestration|Invalid policy type')) if invalid_policy_type?
        return error_with_title(format(s_('SecurityOrchestration|Policy exceeds the maximum of %{limit} actions'), limit: scan_execution_policies_action_limit)) if exceeds_action_limit?
        return error_with_title(format(s_('SecurityOrchestration|Policy exceeds the maximum of %{limit} rule schedules'), limit: scan_execution_policies_schedule_limit)) if exceeds_scan_execution_policy_schedule_limit?
        return error_with_title(format(s_('SecurityOrchestration|Policy exceeds the maximum of %{limit} pipeline execution schedules'), limit: pipeline_execution_schedule_policies_schedule_limit)) if exceeds_pipeline_execution_schedule_policy_schedule_limit?
        return error_with_title(format(s_('SecurityOrchestration|Policy exceeds the maximum of %{limit} approver actions'), limit: approval_action_limit)) if exceeds_approver_action_limit?

        return error_with_title(s_('SecurityOrchestration|Policy cannot be enabled without branch information'), field: :branches) if blank_branch_for_rule?
        return error_with_title(s_('SecurityOrchestration|Policy cannot be enabled for non-existing branches (%{branches})') % { branches: missing_branch_names.join(', ') }, field: :branches) if missing_branch_for_rule?
        return error_with_title(s_('SecurityOrchestration|This merge request approval policy targets the default branch, but the default branch is not protected in this project. To set up this policy, the default branch must be protected.'), field: :branches) if default_branch_unprotected?
        return error_with_title(s_('SecurityOrchestration|Branch types don\'t match any existing branches.'), field: :branches) if invalid_branch_types?
        return error_with_title(s_('SecurityOrchestration|Timezone is invalid'), field: :timezone) if invalid_timezone?
        return error_with_title(s_('SecurityOrchestration|Vulnerability age requires previously existing vulnerability states (detected, confirmed, resolved, or dismissed)'), field: :vulnerability_age) if invalid_vulnerability_age?
        return error_with_title(s_('SecurityOrchestration|Invalid Compliance Framework ID(s)'), field: :compliance_frameworks) if invalid_compliance_framework_ids?

        if required_approvals_exceed_eligible_approvers?
          return errors_with_title(s_('SecurityOrchestration|Required approvals exceed eligible approvers.'), title: s_('SecurityOrchestration|Logic error'), field: :actions, indices: multiple_approvals_failed_action_indices)
        end

        return error_with_title(s_('SecurityOrchestration|Cadence is invalid'), field: :cadence) if invalid_cadence?

        success
      end
      # rubocop:enable Metrics/CyclomaticComplexity
      # rubocop:enable Metrics/PerceivedComplexity
      # rubocop:enable Metrics/AbcSize

      private

      def errors_with_title(message, field: DEFAULT_VALIDATION_ERROR_FIELD, title: nil, level: :error, indices: [])
        validation_errors = indices.map { |index| ValidationError.new(field, level, message, title, index).to_h }

        construct_errors([message], validation_errors)
      end

      def error_with_title(message, field: DEFAULT_VALIDATION_ERROR_FIELD, title: nil, level: :error)
        construct_errors([message], [ValidationError.new(field, level, message, title, 0).to_h])
      end

      def construct_errors(messages, validation_errors)
        pass_back = {
          details: messages,
          validation_errors: validation_errors
        }

        error(s_('SecurityOrchestration|Invalid policy'), :bad_request, pass_back: pass_back)
      end

      def policy_disabled?
        !policy&.[](:enabled)
      end

      def default_branch_unprotected?
        return false unless project_container?
        return false unless approval_policy?
        return false unless policy[:rules]&.any? { |rule| rule[:branch_type] == "default" }

        !ProtectedBranch.protected?(project, project.default_branch)
      end

      def invalid_policy_type?
        return true if policy[:type].blank?

        Security::OrchestrationPolicyConfiguration::AVAILABLE_POLICY_TYPES.exclude?(policy_type)
      end

      def exceeds_approver_action_limit?
        return false unless approval_policy?

        approver_actions_count = policy[:actions]&.count do |action|
          action[:type] == Security::ScanResultPolicy::REQUIRE_APPROVAL
        end || 0

        approver_actions_count > approval_action_limit
      end

      def exceeds_action_limit?
        return false if removing_policy?
        return false if !scan_execution_policy? || scan_execution_policies_action_limit == 0

        (policy[:actions]&.count || 0) > scan_execution_policies_action_limit
      end

      def exceeds_scan_execution_policy_schedule_limit?
        return false if removing_policy?
        return false if !scan_execution_policy? || scan_execution_policies_schedule_limit == 0

        schedule_rules = policy[:rules]&.select { |rule| rule[:type] == ::Security::ScanExecutionPolicy::RULE_TYPES[:schedule] }

        (schedule_rules&.size || 0) > scan_execution_policies_schedule_limit
      end

      def exceeds_pipeline_execution_schedule_policy_schedule_limit?
        return false if removing_policy? || !pipeline_execution_schedule_policy?

        (policy[:schedules]&.size || 0) > pipeline_execution_schedule_policies_schedule_limit
      end

      def blank_name?
        policy[:name].blank?
      end

      def blank_branch_for_rule?
        return false unless scan_execution_policy?

        policy[:rules].any? do |rule|
          rule.values_at(:agents, :branches, :branch_type).all?(&:blank?)
        end
      end

      def missing_branch_for_rule?
        return false if container.blank?
        return false unless project_container?
        return false if pipeline_execution_policy?

        missing_branch_names.present?
      end

      def invalid_compliance_framework_ids?
        return false if project_container?
        return false if compliance_framework_ids.blank?

        container.root_ancestor.compliance_management_frameworks.id_in(compliance_framework_ids).count != compliance_framework_ids.count
      end

      def required_approvals_exceed_eligible_approvers?
        multiple_approvals_failed_action_indices&.any?
      end

      def approvals_required?(action)
        return false unless action

        # For group-level policies the number of role_approvers is project-dependent
        return false if group_container? && action.key?(:role_approvers)

        action.key?(:approvals_required)
      end

      def multiple_approvals_failed_action_indices
        return [] if removing_policy?
        return [] unless approval_policy?
        return [] if approval_requiring_actions.blank?

        result = ::Security::SecurityOrchestrationPolicies::FetchPolicyApproversService.new(
          policy: policy,
          container: container,
          current_user: current_user
        ).execute

        return [] unless result[:status] == :success

        approval_requiring_actions.each_with_object([]).with_index do |(action, indices), index|
          approvers = result[:approvers]&.at(index)
          indices << index if approvers && approvals_required?(action) && invalid_approvals_required?(action, approvers)
        end
      end
      strong_memoize_attr :multiple_approvals_failed_action_indices

      def invalid_approvals_required?(action, approvers)
        approvals_required = action[:approvals_required] || 0

        eligible_user_ids = Set.new
        users, groups, roles = approvers.values_at(:users, :all_groups, :roles)
        eligible_user_ids.merge(users.pluck(:id)) # rubocop:disable CodeReuse/ActiveRecord
        return false if eligible_user_ids.size >= approvals_required

        eligible_user_ids.merge(user_ids_by_groups(groups))
        return false if eligible_user_ids.size >= approvals_required

        eligible_user_ids.merge(user_ids_by_roles(roles))
        eligible_user_ids.size < approvals_required
      end

      def user_ids_by_groups(groups)
        return [] if groups.empty?

        GroupMember.eligible_approvers_by_groups(groups.self_and_ancestors).pluck_user_ids
      end

      def user_ids_by_roles(roles)
        return [] if roles.empty? || group_container?

        roles_map = Gitlab::Access.sym_options_with_owner
        access_levels = roles.filter_map { |role| roles_map[role.to_sym] }

        ProjectAuthorization.eligible_approvers_by_project_id_and_access_levels(project.id, access_levels).pluck_user_ids
      end

      def missing_branch_names
        strong_memoize(:missing_branch_names) do
          next [] if policy[:rules].blank?

          policy[:rules]
            .select { |rule| rule[:agents].blank? }
            .flat_map { |rule| rule[:branches] }
            .compact
            .uniq
            .select { |pattern| RefMatcher.new(pattern).matching(branches_for_project).blank? }
        end
      end

      def policy
        @policy ||= params[:policy]
      end

      def removing_policy?
        params[:operation] == :remove
      end

      def branches_for_project
        strong_memoize(:branches_for_project) do
          container.repository.branch_names
        end
      end

      def invalid_branch_types?
        return false if container.blank? || !project_container? || policy[:rules].blank?

        service = Security::SecurityOrchestrationPolicies::PolicyBranchesService.new(project: container)

        policy[:rules].select { |rule| rule[:branch_type].present? }
                      .any? do |rule|
          if approval_policy?
            service.scan_result_branches([rule]).empty?
          elsif scan_execution_policy? && !service.skip_validation?(rule)
            service.scan_execution_branches([rule]).empty?
          end
        end
      end

      def invalid_timezone?
        return false unless scan_execution_policy?

        policy[:rules].select { |rule| rule[:timezone] }
                      .any? do |rule|
          TZInfo::Timezone.get(rule[:timezone])
          false
        rescue TZInfo::InvalidTimezoneIdentifier
          true
        end
      end

      def invalid_vulnerability_age?
        return false unless approval_policy?

        policy[:rules].select { |rule| rule[:vulnerability_age].present? }
                      .any? do |rule|
          ((rule[:vulnerability_states] || []) & ::Enums::Vulnerability.vulnerability_states.keys.map(&:to_s)).empty?
        end
      end

      def policy_type
        policy[:type].to_sym
      end

      def approval_policy?
        policy_type == :approval_policy
      end

      def scan_execution_policy?
        policy_type == :scan_execution_policy
      end

      def pipeline_execution_policy?
        policy_type == :pipeline_execution_policy
      end

      def pipeline_execution_schedule_policy?
        policy_type == :pipeline_execution_schedule_policy
      end

      def compliance_framework_ids
        policy.dig(:policy_scope, :compliance_frameworks)&.pluck(:id)&.uniq
      end
      strong_memoize_attr :compliance_framework_ids

      def approval_requiring_action
        policy[:actions]&.find { |action| action[:type] == Security::ScanResultPolicy::REQUIRE_APPROVAL }
      end
      strong_memoize_attr :approval_requiring_action

      def approval_requiring_actions
        Array.wrap(policy[:actions]).select { |action| action[:type] == Security::ScanResultPolicy::REQUIRE_APPROVAL }
      end
      strong_memoize_attr :approval_requiring_actions

      def scan_execution_policies_action_limit
        Gitlab::CurrentSettings.scan_execution_policies_action_limit
      end
      strong_memoize_attr :scan_execution_policies_action_limit

      def scan_execution_policies_schedule_limit
        Gitlab::CurrentSettings.scan_execution_policies_schedule_limit
      end
      strong_memoize_attr :scan_execution_policies_schedule_limit

      def pipeline_execution_schedule_policies_schedule_limit
        Security::PipelineExecutionSchedulePolicy::POLICY_LIMIT
      end
      strong_memoize_attr :pipeline_execution_schedule_policies_schedule_limit

      def approval_action_limit
        Security::ScanResultPolicy::APPROVERS_ACTIONS_LIMIT
      end
      strong_memoize_attr :approval_action_limit

      def invalid_cadence?
        return false unless scan_execution_policy?

        policy[:rules].select { |rule| rule[:cadence] }
                      .any? do |rule|
          !(Gitlab::Ci::CronParser.new(rule[:cadence]).cron_valid? && valid_cadence?(rule[:cadence]))
        end
      end
    end
  end
end
