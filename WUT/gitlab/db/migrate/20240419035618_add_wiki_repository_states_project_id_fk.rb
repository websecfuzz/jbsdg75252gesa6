# frozen_string_literal: true

class AddWikiRepositoryStatesProjectIdFk < Gitlab::Database::Migration[2.2]
  milestone '17.0'
  disable_ddl_transaction!

  def up
    add_concurrent_foreign_key :wiki_repository_states, :projects, column: :project_id, on_delete: :cascade
  end

  def down
    with_lock_retries do
      remove_foreign_key :wiki_repository_states, column: :project_id
    end
  end
end
