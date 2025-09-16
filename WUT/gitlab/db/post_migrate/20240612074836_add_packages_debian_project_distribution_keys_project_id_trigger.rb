# frozen_string_literal: true

class AddPackagesDebianProjectDistributionKeysProjectIdTrigger < Gitlab::Database::Migration[2.2]
  milestone '17.1'

  def up
    install_sharding_key_assignment_trigger(
      table: :packages_debian_project_distribution_keys,
      sharding_key: :project_id,
      parent_table: :packages_debian_project_distributions,
      parent_sharding_key: :project_id,
      foreign_key: :distribution_id
    )
  end

  def down
    remove_sharding_key_assignment_trigger(
      table: :packages_debian_project_distribution_keys,
      sharding_key: :project_id,
      parent_table: :packages_debian_project_distributions,
      parent_sharding_key: :project_id,
      foreign_key: :distribution_id
    )
  end
end
