# frozen_string_literal: true

# This concern provides shared functionality to the various approval rule models like
# ApprovalProjectRule, ApprovalGroupRule, and ApprovalMergeRequestRule.
module ApprovalRuleLike
  extend ActiveSupport::Concern
  include EachBatch
  include Importable

  DEFAULT_NAME = 'Default'
  DEFAULT_NAME_FOR_LICENSE_REPORT = 'License-Check'
  DEFAULT_NAME_FOR_COVERAGE = 'Coverage-Check'
  APPROVALS_REQUIRED_MAX = 100
  ALL_MEMBERS = 'All Members'
  NEWLY_DETECTED = 'newly_detected'
  NEW_NEEDS_TRIAGE = 'new_needs_triage'
  NEW_DISMISSED = 'new_dismissed'
  NAME_LENGTH_LIMIT = 1024

  NEWLY_DETECTED_STATUSES = [NEW_NEEDS_TRIAGE, NEW_DISMISSED].freeze
  DEFAULT_VULNERABILITY_STATUSES = [NEW_NEEDS_TRIAGE, NEW_DISMISSED].freeze
  SCAN_RESULT_POLICY_REPORT_TYPES = %w[scan_finding license_scanning any_merge_request].freeze

  included do
    has_and_belongs_to_many :users,
      after_add: :audit_add, after_remove: :audit_remove
    has_and_belongs_to_many :groups,
      class_name: 'Group', join_table: "#{self.table_name}_groups",
      after_add: :audit_add, after_remove: :audit_remove

    has_many :group_members, through: :groups
    has_many :group_users, -> { distinct }, through: :groups, source: :users, disable_joins: true

    belongs_to :security_orchestration_policy_configuration, class_name: 'Security::OrchestrationPolicyConfiguration', optional: true
    belongs_to :scan_result_policy_read,
      class_name: 'Security::ScanResultPolicyRead',
      foreign_key: 'scan_result_policy_id',
      inverse_of: :approval_merge_request_rules,
      optional: true

    belongs_to :approval_policy_rule, class_name: 'Security::ApprovalPolicyRule', optional: true

    enum :report_type, {
      vulnerability: 1, # To be removed after all MRs (related to https://gitlab.com/gitlab-org/gitlab/-/issues/356996) get merged
      license_scanning: 2,
      code_coverage: 3,
      scan_finding: 4,
      any_merge_request: 5
    }

    validates :name, presence: true
    validates :name, length: { maximum: NAME_LENGTH_LIMIT }, if: -> { new_record? || name_changed? }
    validates :approvals_required, numericality: { less_than_or_equal_to: APPROVALS_REQUIRED_MAX, greater_than_or_equal_to: 0 }
    validates :report_type, presence: true, if: :report_approver?

    # We should not import Approval Rules when they are created from Security Policies
    validates :orchestration_policy_idx, absence: true, if: :importing?
    validates :report_type, exclusion: SCAN_RESULT_POLICY_REPORT_TYPES, if: :importing?

    scope :with_users, -> { preload(:users, :group_users) }
    scope :regular_or_any_approver, -> { where(rule_type: [:regular, :any_approver]) }
    scope :not_regular_or_any_approver, -> { where.not(rule_type: [:regular, :any_approver]) }
    scope :for_groups, ->(groups) { joins(:groups).where(approval_project_rules_groups: { group_id: groups }) }
    scope :including_scan_result_policy_read, -> { includes(:scan_result_policy_read) }
    scope :with_scan_result_policy_read, -> { where.not(scan_result_policy_id: nil) }
    scope :for_policy_index, ->(policy_idx) { where(orchestration_policy_idx: policy_idx) }
    scope :exportable, -> { not_from_scan_result_policy } # We are not exporting approval rules that were created from Security Policies
    scope :from_scan_result_policy, -> { where(report_type: SCAN_RESULT_POLICY_REPORT_TYPES) }
    scope :not_from_scan_result_policy, -> do
      where(report_type: nil).or(where.not(report_type: SCAN_RESULT_POLICY_REPORT_TYPES))
    end
    scope :for_policy_configuration, ->(configuration_id) do
      where(security_orchestration_policy_configuration_id: configuration_id)
    end
    scope :for_approval_policy_rules, ->(policy_rules) do
      where(approval_policy_rule: policy_rules)
    end

    scope :for_merge_requests, ->(merge_requests_ids) do
      where(merge_request_id: merge_requests_ids)
    end

    scope :by_report_types, ->(report_types) { where(report_type: report_types) }
  end

  def vulnerability_attribute_false_positive
    nil
  end

  def vulnerability_attribute_fix_available
    nil
  end

  def audit_add
    raise NotImplementedError
  end

  def audit_remove
    raise NotImplementedError
  end

  # Users who are eligible to approve, including specified group members.
  # @return [Array<User>]
  def approvers
    @approvers ||= filter_inactive_approvers(with_role_approvers)
  end

  def approvers_include_user?(user)
    return false if filter_inactive_approvers([user]).empty?

    relation_exists?(users, column: :id, value: user.id) ||
      relation_exists?(scan_result_policy_read_role_approvers, column: :id, value: user.id) ||
      relation_exists?(group_members, column: :user_id, value: user.id) ||
      relation_exists?(code_owner_role_approvers, column: :id, value: user.id)
  end

  def code_owner_role_approvers
    User.none
  end

  def code_owner?
    raise NotImplementedError
  end

  def regular?
    raise NotImplementedError
  end

  def report_approver?
    raise NotImplementedError
  end

  def any_approver?
    raise NotImplementedError
  end

  def user_defined?
    regular? || any_approver?
  end

  def overridden?
    return false unless source_rule.present?

    source_rule.name != name ||
      source_rule.approvals_required != approvals_required ||
      source_rule.user_ids.to_set != user_ids.to_set ||
      source_rule.group_ids.to_set != group_ids.to_set
  end

  def from_scan_result_policy?
    scan_finding? || license_scanning? || any_merge_request?
  end

  def policy_name
    unless scan_result_policy_read.present? && scan_result_policy_read.approval_policy_rule
      return name.gsub(/\s\d+\z/, '')
    end

    scan_result_policy_read.approval_policy_rule.security_policy.name
  end

  private

  def relation_exists?(relation, column:, value:)
    return relation.exists?({ column => value }) unless relation.loaded?

    relation.detect { |item| item.read_attribute(column) == value }
  end

  def with_role_approvers
    if users.loaded? && group_users.loaded?
      users | group_users | scan_result_policy_read_role_approvers | code_owner_role_approvers
    else
      User.from_union([users, group_users, scan_result_policy_read_role_approvers, code_owner_role_approvers])
    end
  end

  def scan_result_policy_read_role_approvers
    return User.none unless scan_result_policy_read

    project.team.members_with_access_level_or_custom_roles(
      levels: scan_result_policy_read.role_approvers,
      member_role_ids: scan_result_policy_read.custom_role_ids_with_permission
    )
  end

  def filter_inactive_approvers(approvers)
    if approvers.respond_to?(:with_state)
      approvers.with_state(:active)
    else
      approvers.select(&:active?)
    end
  end
end
