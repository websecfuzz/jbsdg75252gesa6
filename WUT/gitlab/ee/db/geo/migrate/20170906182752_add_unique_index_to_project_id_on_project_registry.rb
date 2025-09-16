# frozen_string_literal: true

class AddUniqueIndexToProjectIdOnProjectRegistry < ActiveRecord::Migration[4.2]
  include Gitlab::Database::MigrationHelpers

  DOWNTIME = false

  disable_ddl_transaction!

  def up
    remove_concurrent_index :project_registry, :project_id if index_exists? :project_registry, :project_id
    add_concurrent_index :project_registry, :project_id, unique: true
  end

  def down
    remove_concurrent_index :project_registry, :project_id if index_exists? :project_registry, :project_id
    add_concurrent_index :project_registry, :project_id
  end
end
