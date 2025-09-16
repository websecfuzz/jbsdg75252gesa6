# frozen_string_literal: true

class AddDastSiteProfileSecretVariablesProjectIdFk < Gitlab::Database::Migration[2.2]
  milestone '17.1'
  disable_ddl_transaction!

  def up
    add_concurrent_foreign_key :dast_site_profile_secret_variables, :projects, column: :project_id, on_delete: :cascade
  end

  def down
    with_lock_retries do
      remove_foreign_key :dast_site_profile_secret_variables, column: :project_id
    end
  end
end
