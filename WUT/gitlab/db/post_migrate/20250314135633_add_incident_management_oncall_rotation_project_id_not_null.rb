# frozen_string_literal: true

class AddIncidentManagementOncallRotationProjectIdNotNull < Gitlab::Database::Migration[2.2]
  milestone '17.11'
  disable_ddl_transaction!

  def up
    add_not_null_constraint :incident_management_oncall_rotations, :project_id
  end

  def down
    remove_not_null_constraint :incident_management_oncall_rotations, :project_id
  end
end
