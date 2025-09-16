# frozen_string_literal: true

class AddTerraformStateVersionsProjectIdTrigger < Gitlab::Database::Migration[2.2]
  milestone '17.1'

  def up
    install_sharding_key_assignment_trigger(
      table: :terraform_state_versions,
      sharding_key: :project_id,
      parent_table: :terraform_states,
      parent_sharding_key: :project_id,
      foreign_key: :terraform_state_id
    )
  end

  def down
    remove_sharding_key_assignment_trigger(
      table: :terraform_state_versions,
      sharding_key: :project_id,
      parent_table: :terraform_states,
      parent_sharding_key: :project_id,
      foreign_key: :terraform_state_id
    )
  end
end
