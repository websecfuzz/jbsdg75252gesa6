# frozen_string_literal: true

class IndexApprovalProjectRulesProtectedBranchesOnProjectId < Gitlab::Database::Migration[2.2]
  milestone '17.5'
  disable_ddl_transaction!

  INDEX_NAME = 'index_approval_project_rules_protected_branches_on_project_id'

  def up
    add_concurrent_index :approval_project_rules_protected_branches, :project_id, name: INDEX_NAME
  end

  def down
    remove_concurrent_index_by_name :approval_project_rules_protected_branches, INDEX_NAME
  end
end
