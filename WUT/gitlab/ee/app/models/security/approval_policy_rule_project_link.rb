# frozen_string_literal: true

module Security
  class ApprovalPolicyRuleProjectLink < ApplicationRecord
    include EachBatch

    self.table_name = 'approval_policy_rule_project_links'

    belongs_to :project
    belongs_to :approval_policy_rule,
      class_name: 'Security::ApprovalPolicyRule',
      inverse_of: :approval_policy_rule_project_links

    validates :approval_policy_rule, uniqueness: { scope: :project_id }

    scope :for_project, ->(project) { where(project: project) }
    scope :for_policy_rules, ->(policy_rules) { where(approval_policy_rule: policy_rules) }
  end
end
