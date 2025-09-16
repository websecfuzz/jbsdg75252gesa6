# frozen_string_literal: true

module Security
  module ScanResultPolicies
    module ApprovalRules
      class CreateService < BaseService
        def execute
          approval_policy_rules.each do |approval_policy_rule|
            if approval_actions.blank?
              create_rule(approval_policy_rule)
              next
            end

            approval_actions.each_with_index do |approval_action, action_index|
              create_rule(approval_policy_rule, action_index, approval_action)
            end
          end
        end

        private

        def create_approval_rule?(rule)
          return true unless rule.type_any_merge_request?

          # For `any_merge_request` rules, the approval rules can be created without approvers and can override
          # project approval settings in general.
          # The violations in this case are handled via SyncAnyMergeRequestRulesService
          approval_actions.present?
        end

        def create_rule(approval_policy_rule, action_index = 0, approval_action = nil)
          approval_rule = project_approval_rules_map.dig(approval_policy_rule.id, action_index)

          return if approval_rule.present?
          return if scan_result_policy_reads_map.dig(approval_policy_rule.id, action_index).present?

          scan_result_policy_read = create_scan_result_policy(approval_policy_rule, action_index, approval_action)

          return unless create_approval_rule?(approval_policy_rule)

          sync_license_scanning_rule(approval_policy_rule, scan_result_policy_read)

          result = ::ApprovalRules::CreateService.new(
            project, author, rule_params(approval_policy_rule, scan_result_policy_read, action_index, approval_action)
          ).execute

          return if result.success?

          log_service_failure(
            'approval_rule_creation_failed', approval_policy_rule, scan_result_policy_read,
            action_index, result.errors)
        end

        def create_scan_result_policy(approval_policy_rule, action_index = 0, approval_action = nil)
          security_policy.security_orchestration_policy_configuration.scan_result_policy_reads.create!(
            scan_result_policy_read_params(approval_policy_rule, action_index, approval_action)
          )
        end
      end
    end
  end
end
