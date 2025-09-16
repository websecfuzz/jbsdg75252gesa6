# frozen_string_literal: true

class AddClusterAgentMigrationsClusterFk < Gitlab::Database::Migration[2.2]
  disable_ddl_transaction!
  milestone '17.9'

  def up
    add_concurrent_foreign_key :cluster_agent_migrations, :clusters, column: :cluster_id, on_delete: :cascade
  end

  def down
    with_lock_retries do
      remove_foreign_key :cluster_agent_migrations, column: :cluster_id
    end
  end
end
