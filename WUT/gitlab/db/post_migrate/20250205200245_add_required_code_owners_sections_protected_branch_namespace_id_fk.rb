# frozen_string_literal: true

class AddRequiredCodeOwnersSectionsProtectedBranchNamespaceIdFk < Gitlab::Database::Migration[2.2]
  milestone '17.9'
  disable_ddl_transaction!

  def up
    add_concurrent_foreign_key :required_code_owners_sections, :namespaces, column: :protected_branch_namespace_id,
      on_delete: :cascade
  end

  def down
    with_lock_retries do
      remove_foreign_key :required_code_owners_sections, column: :protected_branch_namespace_id
    end
  end
end
