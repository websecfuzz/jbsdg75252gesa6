# frozen_string_literal: true

class CreateScanExecutionPolicyRules < Gitlab::Database::Migration[2.2]
  milestone '17.1'

  UNIQUE_INDEX_NAME = "index_scan_execution_policy_rules_on_unique_policy_rule_index"
  FK_INDEX_NAME = "index_scan_execution_policy_rules_on_policy_mgmt_project_id"

  def change
    create_table :scan_execution_policy_rules do |t|
      t.references :security_policy,
        null: false,
        foreign_key: { on_delete: :cascade },
        index: false
      t.references :security_policy_management_project,
        null: false,
        foreign_key: { on_delete: :cascade, to_table: :projects },
        index: false
      t.timestamps_with_timezone null: false
      t.integer :rule_index, limit: 2, null: false
      t.integer :type, limit: 2, null: false
      t.jsonb :content, default: {}, null: false
    end

    add_index(
      :scan_execution_policy_rules,
      %i[security_policy_id rule_index],
      unique: true,
      name: UNIQUE_INDEX_NAME)

    add_index(
      :scan_execution_policy_rules,
      :security_policy_management_project_id,
      name: FK_INDEX_NAME)
  end
end
