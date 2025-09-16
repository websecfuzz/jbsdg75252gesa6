# frozen_string_literal: true

class AddMergeRequestsApprovalRulesUsersUserFk < Gitlab::Database::Migration[2.2]
  milestone '17.10'
  disable_ddl_transaction!

  def up
    add_concurrent_foreign_key :merge_requests_approval_rules_approver_users, :users, column: :user_id,
      on_delete: :cascade
  end

  def down
    with_lock_retries do
      remove_foreign_key :merge_requests_approval_rules_approver_users, column: :user_id
    end
  end
end
