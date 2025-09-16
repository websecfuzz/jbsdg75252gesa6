# frozen_string_literal: true

class AddOrganizationToSbomSourcePackages < Gitlab::Database::Migration[2.2]
  disable_ddl_transaction!

  milestone '17.3'

  INDEX_NAME = 'index_sbom_source_packages_on_organization_id'

  def up
    with_lock_retries do
      add_column :sbom_source_packages, :organization_id, :bigint, null: false,
        default: Organizations::Organization::DEFAULT_ORGANIZATION_ID,
        if_not_exists: true
    end

    add_concurrent_index :sbom_source_packages, :organization_id, name: INDEX_NAME
  end

  def down
    remove_concurrent_index_by_name :sbom_source_packages, INDEX_NAME

    with_lock_retries do
      remove_column :sbom_source_packages, :organization_id, if_exists: true
    end
  end
end
