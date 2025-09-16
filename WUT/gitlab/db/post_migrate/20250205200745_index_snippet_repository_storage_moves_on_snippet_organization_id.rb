# frozen_string_literal: true

class IndexSnippetRepositoryStorageMovesOnSnippetOrganizationId < Gitlab::Database::Migration[2.2]
  milestone '17.9'
  disable_ddl_transaction!

  INDEX_NAME = 'index_snippet_repository_storage_moves_on_snippet_organization_'

  def up
    add_concurrent_index :snippet_repository_storage_moves, :snippet_organization_id, name: INDEX_NAME
  end

  def down
    remove_concurrent_index_by_name :snippet_repository_storage_moves, INDEX_NAME
  end
end
