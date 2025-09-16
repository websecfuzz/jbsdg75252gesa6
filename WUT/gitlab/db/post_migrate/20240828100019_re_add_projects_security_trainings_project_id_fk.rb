# frozen_string_literal: true

class ReAddProjectsSecurityTrainingsProjectIdFk < Gitlab::Database::Migration[2.2]
  milestone '17.4'
  disable_ddl_transaction!

  FOREIGN_KEY_NAME = "fk_rails_f80240fae0"

  def up
    add_concurrent_foreign_key(:security_trainings, :projects,
      name: FOREIGN_KEY_NAME, column: :project_id,
      target_column: :id, on_delete: :cascade, validate: false)
  end

  def down
    with_lock_retries do
      remove_foreign_key_if_exists(:security_trainings, :projects,
        name: FOREIGN_KEY_NAME, reverse_lock_order: true)
    end
  end
end
