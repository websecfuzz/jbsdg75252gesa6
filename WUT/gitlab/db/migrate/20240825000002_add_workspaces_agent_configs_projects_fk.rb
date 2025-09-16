# frozen_string_literal: true

class AddWorkspacesAgentConfigsProjectsFk < Gitlab::Database::Migration[2.2]
  milestone "17.4"
  disable_ddl_transaction!

  TABLE_NAME = :workspaces_agent_configs

  def up
    add_concurrent_foreign_key TABLE_NAME, :projects, column: :project_id, on_delete: :cascade
  end

  def down
    with_lock_retries { remove_foreign_key TABLE_NAME, column: :project_id }
  end
end
