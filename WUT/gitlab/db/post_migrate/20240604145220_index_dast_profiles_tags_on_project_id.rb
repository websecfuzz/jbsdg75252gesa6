# frozen_string_literal: true

class IndexDastProfilesTagsOnProjectId < Gitlab::Database::Migration[2.2]
  milestone '17.1'
  disable_ddl_transaction!

  INDEX_NAME = 'index_dast_profiles_tags_on_project_id'

  def up
    add_concurrent_index :dast_profiles_tags, :project_id, name: INDEX_NAME
  end

  def down
    remove_concurrent_index_by_name :dast_profiles_tags, INDEX_NAME
  end
end
