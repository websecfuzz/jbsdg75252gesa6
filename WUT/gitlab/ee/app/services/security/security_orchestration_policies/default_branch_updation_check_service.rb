# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class DefaultBranchUpdationCheckService < BaseProjectService
      def execute
        return false unless project.licensed_feature_available?(:security_orchestration_policies)

        applicable_branches = PolicyBranchesService.new(project: project).scan_result_branches(rules)

        applicable_branches.include?(project.default_branch)
      end

      private

      def rules
        blocking_policies = applicable_scan_result_policies.select do |policy|
          policy.dig(:approval_settings, :block_branch_modification)
        end

        blocking_policies.pluck(:rules).flatten # rubocop: disable CodeReuse/ActiveRecord -- blocking_policies is not expected to be an ActiveRecord::Relation but an Array
      end

      def applicable_scan_result_policies
        policy_scope_checker = Security::SecurityOrchestrationPolicies::PolicyScopeChecker.new(project: project)

        project
          .all_security_orchestration_policy_configurations
          .flat_map(&:active_scan_result_policies)
          .select { |policy| policy_scope_checker.policy_applicable?(policy) }
      end
    end
  end
end
