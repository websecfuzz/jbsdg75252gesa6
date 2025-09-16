# frozen_string_literal: true

class RenamePreReceiveSecretDetectionEnabledToSecretPushProtectionAvailable < Gitlab::Database::Migration[2.2]
  milestone '17.9'
  disable_ddl_transaction!

  TABLE = :application_settings

  def up
    rename_column_concurrently TABLE, :pre_receive_secret_detection_enabled, :secret_push_protection_available
  end

  def down
    undo_rename_column_concurrently TABLE, :pre_receive_secret_detection_enabled, :secret_push_protection_available
  end
end
