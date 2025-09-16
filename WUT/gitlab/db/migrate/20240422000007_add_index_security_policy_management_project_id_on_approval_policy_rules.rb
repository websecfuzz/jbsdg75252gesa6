# frozen_string_literal: true

class AddIndexSecurityPolicyManagementProjectIdOnApprovalPolicyRules < Gitlab::Database::Migration[2.2]
  milestone '17.0'
  disable_ddl_transaction!

  INDEX_NAME = 'index_approval_policy_rules_on_policy_management_project_id'

  def up
    add_concurrent_index :approval_policy_rules, :security_policy_management_project_id, name: INDEX_NAME
  end

  def down
    remove_concurrent_index_by_name :approval_policy_rules, INDEX_NAME
  end
end
