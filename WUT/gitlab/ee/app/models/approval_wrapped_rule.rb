# frozen_string_literal: true

# A common state computation interface to wrap around ApprovalRuleLike models.
#
# There are 2 types of approval rules (`ApprovalProjectRule` and
# `ApprovalMergeRequestRule`), we want to get the data we need for the approval
# state of each rule via a common interface. That depends on the approvals data
# of a merge request.
#
# `ApprovalProjectRule` doesn't have access to the merge request unlike
# `ApprovalMergeRequestRule`. Given that, instead of having different checks and
# methods when dealing with a `ApprovalProjectRule`, having a common interface
# is easier and simpler to interact with.
#
# Different types of `ApprovalWrappedRule` also helps since we have different
# `rule_type`s that can behave differently.
class ApprovalWrappedRule
  extend Forwardable
  include Gitlab::Utils::StrongMemoize

  attr_reader :merge_request
  attr_reader :approval_rule

  def_delegators(
    :@approval_rule,
    :regular?, :any_approver?, :code_owner?, :report_approver?,
    :overridden?, :id, :users, :groups, :code_owner, :from_scan_result_policy?,
    :source_rule, :rule_type, :report_type, :approvals_required, :section, :to_global_id, :rule_project
  )

  def self.wrap(merge_request, rule)
    if rule.any_approver?
      ApprovalWrappedAnyApproverRule.new(merge_request, rule)
    elsif rule.code_owner?
      ApprovalWrappedCodeOwnerRule.new(merge_request, rule)
    else
      ApprovalWrappedRule.new(merge_request, rule)
    end
  end

  def initialize(merge_request, approval_rule)
    @merge_request = merge_request
    @approval_rule = approval_rule
  end

  def project
    @merge_request.target_project
  end

  def approvers
    strong_memoize(:approvers) do
      filter_approvers(@approval_rule.approvers)
    end
  end

  def declarative_policy_delegate
    @approval_rule
  end

  # @return [Array<User>] of users who have approved the merge request
  #
  # This is dynamically calculated unless it is persisted as `approved_approvers`.
  #
  # After merge, the approval state should no longer change.
  # We persist this so if project level rule is changed in the future,
  # return result won't be affected.
  #
  # For open MRs, it is dynamically calculated because:
  # - Additional complexity to add update hooks
  # - DB updating many MRs for one project rule change is inefficient
  def approved_approvers
    if merge_request.merged? && approval_rule.is_a?(ApprovalMergeRequestRule) && approval_rule.approved_approvers.any?
      return approval_rule.approved_approvers
    end

    strong_memoize(:approved_approvers) do
      approvers.select do |approver|
        overall_approver_ids.include?(approver.id)
      end
    end
  end

  def commented_approvers
    strong_memoize(:commented_approvers) do
      merge_request.user_note_authors & approvers
    end
  end

  def approved?
    strong_memoize(:approved) do
      approvals_left <= 0 || (invalid_rule? && allow_merge_when_invalid?)
    end
  end

  def invalid_rule?
    !any_approver? && approvals_required > approvers.size
  end

  def allow_merge_when_invalid?
    return true if fail_open?

    !from_scan_result_policy? ||
      Security::OrchestrationPolicyConfiguration.policy_management_project?(project)
  end

  def scan_result_policies
    policy_configuration_id = approval_rule.security_orchestration_policy_configuration_id

    return unless policy_configuration_id

    merge_request
      .approval_rules.for_policy_configuration(policy_configuration_id)
      .for_policy_index(approval_rule.orchestration_policy_idx)
      .select(:report_type, :name, :approvals_required, :approval_policy_action_idx)
  end

  def policy_has_multiple_actions?
    policy_configuration = approval_rule.security_orchestration_policy_configuration
    return false unless policy_configuration

    scan_result_policies.any? { |rule| rule.approval_policy_action_idx > 0 }
  end

  # Number of approvals remaining (excluding existing approvals)
  # before the rule is considered approved.
  #
  # If there are fewer potential approvers than approvals left,
  # users should either reduce `approvals_required`
  # and/or allow MR authors to approve their own merge
  # requests (in case only one approval is needed).
  def approvals_left
    strong_memoize(:approvals_left) do
      next 0 if invalid_rule? && fail_open?

      approvals_left_count = approvals_required - approved_approvers.size

      [approvals_left_count, 0].max
    end
  end

  def unactioned_approvers
    approvers - approved_approvers
  end

  def name
    return approval_rule.name unless from_scan_result_policy?

    if policy_has_multiple_actions?
      "#{approval_rule.policy_name} - Action #{approval_rule.approval_policy_action_idx + 1}"
    else
      approval_rule.policy_name
    end
  end

  def fail_open?
    approval_rule.scan_result_policy_read&.fail_open? || false
  end

  private

  def filter_approvers(approvers)
    filtered_approvers =
      ApprovalState.filter_author(approvers, merge_request)

    ApprovalState.filter_committers(filtered_approvers, merge_request)
  end

  def overall_approver_ids
    strong_memoize(:overall_approver_ids) do
      current_approvals = merge_request.approvals

      if current_approvals.is_a?(ActiveRecord::Relation) && !current_approvals.loaded?
        current_approvals.distinct.pluck(:user_id)
      else
        current_approvals.map(&:user_id).to_set
      end
    end
  end
end
