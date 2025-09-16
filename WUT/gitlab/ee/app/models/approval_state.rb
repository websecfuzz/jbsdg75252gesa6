# frozen_string_literal: true

require 'forwardable'

# A state object to centralize logic related to various approval related states.
# This reduce interface footprint on MR and allows easier cache invalidation.
class ApprovalState
  extend Forwardable
  include ::Gitlab::Utils::StrongMemoize

  attr_reader :merge_request, :project

  def_delegators :@merge_request, :merge_status, :approved_by_users, :approvals, :approval_feature_available?, :approved_by?
  alias_method :approved_approvers, :approved_by_users

  def initialize(merge_request, target_branch: nil)
    @merge_request = merge_request
    @project = merge_request.target_project
    @target_branch = target_branch || merge_request.target_branch
  end

  # Excludes the author if 'author-approval' is explicitly disabled on project settings.
  # For Ultimate projects, a scan result policy may override this behaviour by its
  # `approval_settings.prevent_approval_by_author` attribute.
  def self.filter_author(users, merge_request)
    return users if merge_request.merge_requests_author_approval?

    if users.is_a?(ActiveRecord::Relation) && !users.loaded?
      users.where.not(id: merge_request.author_id)
    else
      users - [merge_request.author]
    end
  end

  # Excludes the author if 'committers-approval' is explicitly disabled on project settings.
  def self.filter_committers(users, merge_request)
    return users unless merge_request.merge_requests_disable_committers_approval?

    if users.is_a?(ActiveRecord::Relation) && !users.loaded?
      users.where.not(id: merge_request.committers(with_merge_commits: true, include_author_when_signed: true).select(:id))
    else
      users - merge_request.committers(with_merge_commits: true, lazy: true, include_author_when_signed: true)
    end
  end

  def wrapped_approval_rules
    strong_memoize(:wrapped_approval_rules) do
      next [] unless approval_feature_available?

      if merge_request.merged?
        # After merging, we have historical data that we contain invalid approval rules associated with
        # the merge request. We should remove any of these invalid approver rules.
        # We also removed any that are not approved, as they would have not been
        # applicable at the time of merge.
        (all_approval_rules - invalid_approvers_rules).select(&:approved?)
      else
        all_approval_rules
      end
    end
  end

  # Determines which set of rules to use (MR or project)
  def approval_rules_overwritten?
    project.can_override_approvers? && user_defined_merge_request_rules.any?
  end
  alias_method :approvers_overwritten?, :approval_rules_overwritten?

  def approval_needed?
    return false unless project.feature_available?(:merge_request_approvers)

    wrapped_approval_rules.any? { |rule| rule.approvals_required > 0 }
  end

  def approved?
    return false if temporarily_unapproved?

    wrapped_approval_rules.all?(&:approved?)
  end
  strong_memoize_attr :approved?

  def expire_unapproved_key!
    Gitlab::Redis::SharedState.with do |redis|
      redis.del(temporarily_unapproved_cache_key)
    end
  end

  def temporarily_unapprove!
    Gitlab::Redis::SharedState.with do |redis|
      redis.set(temporarily_unapproved_cache_key, true, ex: 15.seconds)
    end
  end

  def temporarily_unapproved?
    Gitlab::Redis::SharedState.with do |redis|
      redis.exists?(temporarily_unapproved_cache_key)
    end
  end

  def approvals_required
    strong_memoize(:approvals_required) do
      [regular_rules_required + code_owner_rules_required + report_approver_rules_required, any_approver_rules_required].max
    end
  end

  def code_owner_rules_required
    strong_memoize(:code_owner_rules_required) do
      code_owner_rules.sum(&:approvals_required)
    end
  end

  def report_approver_rules_required
    strong_memoize(:report_approver_rules_required) do
      report_approver_rules.sum(&:approvals_required)
    end
  end

  def regular_rules_required
    strong_memoize(:regular_rules_required) do
      regular_approval_rules.sum(&:approvals_required)
    end
  end

  def any_approver_rules_required
    strong_memoize(:any_approver_rules_required) do
      any_approver_approval_rules.sum(&:approvals_required)
    end
  end

  # Number of approvals remaining (excluding existing approvals) before the MR is
  # considered approved.
  def approvals_left
    strong_memoize(:approvals_left) do
      [regular_rules_left + code_owner_rules_left + report_approver_rules_left, any_approver_rules_left].max
    end
  end

  def code_owner_rules_left
    strong_memoize(:code_owner_rules_left) do
      code_owner_rules.sum(&:approvals_left)
    end
  end

  def report_approver_rules_left
    strong_memoize(:report_approver_rules_left) do
      report_approver_rules.sum(&:approvals_left)
    end
  end

  def regular_rules_left
    strong_memoize(:regular_rules_left) do
      regular_approval_rules.sum(&:approvals_left)
    end
  end

  def any_approver_rules_left
    strong_memoize(:any_approver_rules_left) do
      any_approver_approval_rules.sum(&:approvals_left)
    end
  end

  def approval_rules_left
    rules = if any_approver_rules_left <= regular_rules_left + code_owner_rules_left + report_approver_rules_left
              wrapped_approval_rules.reject(&:any_approver?)
            else
              wrapped_approval_rules
            end

    rules.reject(&:approved?)
  end

  def approvers
    strong_memoize(:approvers) { filtered_approvers(target: :approvers) }
  end

  # @param code_owner [Boolean]
  # @param target [:approvers, :users]
  # @param unactioned [Boolean]
  def filtered_approvers(code_owner: true, target: :approvers, unactioned: false)
    rules = user_defined_rules + report_approver_rules
    rules.concat(code_owner_rules) if code_owner

    filter_approvers(rules.flat_map(&target), unactioned: unactioned)
  end

  def unactioned_approvers
    strong_memoize(:unactioned_approvers) { approvers - approved_approvers }
  end

  # TODO order by relevance
  def suggested_approvers(current_user:)
    # Ignore approvers from rules containing hidden groups
    rules = wrapped_approval_rules.reject do |rule|
      ApprovalRules::GroupFinder.new(rule, current_user).contains_hidden_groups?
    end

    filter_approvers(rules.flat_map(&:approvers), unactioned: true)
  end

  def eligible_for_approval_by?(user)
    return false unless user
    return false unless user.can?(:approve_merge_request, merge_request)

    return true if unactioned_approvers.include?(user)
    # Users can only approve once.
    return false if approved_by?(user)
    # At this point, follow self-approval rules. Otherwise authors must
    # have been in the list of unactioned_approvers to have been approved.
    return false if !authors_can_approve? && merge_request.author == user

    if !committers_can_approve? && merge_request.committers(include_author_when_signed: true).include?(user)
      return false
    end

    true
  end

  def authors_can_approve?
    merge_request.merge_requests_author_approval?
  end

  def committers_can_approve?
    !merge_request.merge_requests_disable_committers_approval?
  end

  # TODO: remove after #1979 is closed
  # This is a temporary method for backward compatibility
  # before introduction of approval rules.
  # This avoids re-queries.
  # https://gitlab.com/gitlab-org/gitlab/issues/33329
  def first_regular_rule
    strong_memoize(:first_regular_rule) do
      user_defined_rules.first
    end
  end

  def user_defined_rules
    strong_memoize(:user_defined_rules) do
      if approval_rules_overwritten? || (merge_request.merged? && user_defined_merge_request_rules.any?)
        user_defined_merge_request_rules
      else
        project.visible_user_defined_rules(branch: target_branch).map do |rule|
          ApprovalWrappedRule.wrap(merge_request, rule)
        end
      end
    end
  end

  # This is the required + optional approval count
  def total_approvals_count
    approvals.size
  end

  def invalid_approvers_rules
    strong_memoize(:invalid_approvers_rules) do
      all_approval_rules.select do |rule|
        next if rule.any_approver?
        next if rule.approvers.any? && rule.approvers.size >= rule.approvals_required

        if rule.code_owner?
          rule.branch_requires_code_owner_approval?
        else
          rule.approvals_required > rule.approvers.size
        end
      end
    end
  end

  private

  attr_reader :target_branch

  def temporarily_unapproved_cache_key
    "mr_#{merge_request.id}_cannot_merge"
  end

  def filter_approvers(approvers, unactioned:)
    approvers = approvers.uniq
    approvers -= approved_approvers if unactioned
    approvers = self.class.filter_author(approvers, merge_request)

    self.class.filter_committers(approvers, merge_request)
  end

  def user_defined_merge_request_rules
    strong_memoize(:user_defined_merge_request_rules) do
      regular_rules =
        wrapped_rules.select(&:regular?).sort_by(&:id)

      any_approver_rules =
        wrapped_rules.select(&:any_approver?)

      rules = any_approver_rules + regular_rules
      project.multiple_approval_rules_available? ? rules : rules.take(1)
    end
  end

  def code_owner_rules
    strong_memoize(:code_owner_rules) do
      wrapped_rules.select(&:code_owner?)
    end
  end

  def report_approver_rules
    strong_memoize(:report_approver_rules) do
      wrapped_rules.select(&:report_approver?)
    end
  end

  def regular_approval_rules
    strong_memoize(:regular_approval_rules) do
      wrapped_approval_rules.select(&:regular?)
    end
  end

  def any_approver_approval_rules
    strong_memoize(:any_approver_approval_rules) do
      wrapped_approval_rules.select(&:any_approver?)
    end
  end

  def wrapped_rules
    strong_memoize(:wrapped_rules) do
      rules = if merge_request.merged?
                merge_request.applicable_post_merge_approval_rules
              elsif Feature.enabled?(:v2_approval_rules, project)
                merge_request.v2_approval_rules
              else
                merge_request.approval_rules.applicable_to_branch(target_branch)
              end

      grouped_merge_request_rules = rules.group_by do |rule|
        rule.from_scan_result_policy? ? :scan_finding : rule.report_type
      end

      grouped_merge_request_rules.flat_map do |report_type, merge_request_rules|
        Approvals::WrappedRuleSet.wrap(merge_request, merge_request_rules, report_type).wrapped_rules
      end
    end
  end

  def all_approval_rules
    strong_memoize(:all_approval_rules) do
      next [] unless approval_feature_available?

      user_defined_rules + code_owner_rules + report_approver_rules
    end
  end
end
