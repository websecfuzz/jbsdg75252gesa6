# frozen_string_literal: true

class IndexPackagesComposerMetadataOnProjectId < Gitlab::Database::Migration[2.2]
  milestone '17.5'
  disable_ddl_transaction!

  INDEX_NAME = 'index_packages_composer_metadata_on_project_id'

  def up
    add_concurrent_index :packages_composer_metadata, :project_id, name: INDEX_NAME
  end

  def down
    remove_concurrent_index_by_name :packages_composer_metadata, INDEX_NAME
  end
end
