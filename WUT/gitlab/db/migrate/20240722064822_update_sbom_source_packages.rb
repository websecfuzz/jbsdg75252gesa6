# frozen_string_literal: true

class UpdateSbomSourcePackages < Gitlab::Database::Migration[2.2]
  disable_ddl_transaction!

  restrict_gitlab_migration gitlab_schema: :gitlab_sec

  milestone '17.3'

  class SbomSourcePackage < MigrationRecord
    self.table_name = "sbom_source_packages"
  end

  def up
    # no-op
  end

  def down
    SbomSourcePackage.where.not(organization_id: 1).delete_all
  end
end
