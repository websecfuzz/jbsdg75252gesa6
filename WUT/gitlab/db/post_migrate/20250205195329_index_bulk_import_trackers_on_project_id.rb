# frozen_string_literal: true

class IndexBulkImportTrackersOnProjectId < Gitlab::Database::Migration[2.2]
  milestone '17.9'
  disable_ddl_transaction!

  INDEX_NAME = 'index_bulk_import_trackers_on_project_id'

  def up
    add_concurrent_index :bulk_import_trackers, :project_id, name: INDEX_NAME
  end

  def down
    remove_concurrent_index_by_name :bulk_import_trackers, INDEX_NAME
  end
end
