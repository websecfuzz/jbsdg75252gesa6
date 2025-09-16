# frozen_string_literal: true

class AddIndexOnLastSyncedAtToFileRegistry < Gitlab::Database::Migration[2.2]
  disable_ddl_transaction!

  milestone '17.9'

  TABLE = :file_registry
  INDEX = 'index_file_registry_on_last_synced_at'

  def up
    add_concurrent_index TABLE, :last_synced_at, name: INDEX
  end

  def down
    remove_concurrent_index_by_name TABLE, INDEX
  end
end
