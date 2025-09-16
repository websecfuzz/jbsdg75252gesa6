# frozen_string_literal: true

class AddFkToComplianceRequirementsOnFrameworkId < Gitlab::Database::Migration[2.2]
  milestone '17.3'
  disable_ddl_transaction!

  def up
    add_concurrent_foreign_key :compliance_requirements, :compliance_management_frameworks, column: :framework_id,
      on_delete: :cascade, reverse_lock_order: true
  end

  def down
    with_lock_retries do
      remove_foreign_key_if_exists :compliance_requirements, column: :framework_id, reverse_lock_order: true
    end
  end
end
