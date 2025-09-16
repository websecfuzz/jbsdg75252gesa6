# frozen_string_literal: true

class RenamePackagesProtectionRulesProtectedAccessLevelToMinimumAccessLevel < Gitlab::Database::Migration[2.2]
  milestone '17.1'

  disable_ddl_transaction!

  TABLE = :packages_protection_rules

  def up
    rename_column_concurrently TABLE, :push_protected_up_to_access_level, :minimum_access_level_for_push
  end

  def down
    undo_rename_column_concurrently TABLE, :push_protected_up_to_access_level, :minimum_access_level_for_push
  end
end
