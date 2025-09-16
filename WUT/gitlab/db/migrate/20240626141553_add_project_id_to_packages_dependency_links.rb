# frozen_string_literal: true

class AddProjectIdToPackagesDependencyLinks < Gitlab::Database::Migration[2.2]
  milestone '17.2'

  def change
    add_column :packages_dependency_links, :project_id, :bigint
  end
end
