# frozen_string_literal: true

class AddBulkImportTrackersNamespaceIdFk < Gitlab::Database::Migration[2.2]
  milestone '17.9'
  disable_ddl_transaction!

  def up
    add_concurrent_foreign_key :bulk_import_trackers, :namespaces, column: :namespace_id, on_delete: :cascade
  end

  def down
    with_lock_retries do
      remove_foreign_key :bulk_import_trackers, column: :namespace_id
    end
  end
end
