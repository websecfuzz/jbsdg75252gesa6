# frozen_string_literal: true

class ValidateProjectIdNotNullConstraintOnCiStages < Gitlab::Database::Migration[2.2]
  milestone '17.7'

  TABLE_NAME = :p_ci_stages
  COLUMN_NAME = :project_id
  CONSTRAINT_NAME = :check_74835fc631

  def up
    validate_not_null_constraint(TABLE_NAME, COLUMN_NAME, constraint_name: CONSTRAINT_NAME)
  end

  def down
    # no-op
  end
end
