# frozen_string_literal: true

class IndexPackagesDebianProjectDistributionKeysOnProjectId < Gitlab::Database::Migration[2.2]
  milestone '17.1'
  disable_ddl_transaction!

  INDEX_NAME = 'index_packages_debian_project_distribution_keys_on_project_id'

  def up
    add_concurrent_index :packages_debian_project_distribution_keys, :project_id, name: INDEX_NAME
  end

  def down
    remove_concurrent_index_by_name :packages_debian_project_distribution_keys, INDEX_NAME
  end
end
