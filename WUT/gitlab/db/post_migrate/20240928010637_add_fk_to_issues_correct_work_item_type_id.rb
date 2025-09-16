# frozen_string_literal: true

class AddFkToIssuesCorrectWorkItemTypeId < Gitlab::Database::Migration[2.2]
  milestone '17.5'

  disable_ddl_transaction!

  def up
    add_concurrent_foreign_key :issues,
      :work_item_types,
      column: :correct_work_item_type_id,
      target_column: :correct_id,
      validate: false,
      on_delete: nil
  end

  def down
    with_lock_retries do
      remove_foreign_key_if_exists :issues, column: :correct_work_item_type_id
    end
  end
end
