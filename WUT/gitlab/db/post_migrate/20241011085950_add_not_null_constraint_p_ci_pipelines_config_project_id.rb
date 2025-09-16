# frozen_string_literal: true

class AddNotNullConstraintPCiPipelinesConfigProjectId < Gitlab::Database::Migration[2.2]
  disable_ddl_transaction!
  milestone '17.6'

  TABLE_NAME = :p_ci_pipelines_config
  COLUMN_NAME = :project_id
  CONSTRAINT_NAME = :check_b2a19dd79a

  def up
    add_not_null_constraint(TABLE_NAME, COLUMN_NAME, constraint_name: CONSTRAINT_NAME, validate: false)
  end

  def down
    remove_not_null_constraint(TABLE_NAME, COLUMN_NAME, constraint_name: CONSTRAINT_NAME)
  end
end
