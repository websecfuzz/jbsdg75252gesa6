# frozen_string_literal: true

class CreateSubscriptionProvisionSyncs < Gitlab::Database::Migration[2.2]
  milestone '17.8'

  UNIQUE_INDEX_NAME = 'uniq_idx_provision_syncs_on_namespace_id_and_sync_requested_at'

  def change
    create_table :subscription_provision_syncs do |t| # rubocop:disable Migration/EnsureFactoryForTable -- https://gitlab.com/gitlab-org/gitlab/-/issues/468630
      t.bigint :namespace_id, null: false
      t.datetime_with_timezone :sync_requested_at, null: false
      t.timestamps_with_timezone null: false
      t.jsonb :attrs, null: false

      t.index [:namespace_id, :sync_requested_at], unique: true,
        order: { sync_requested_at: :desc }, name: UNIQUE_INDEX_NAME
    end
  end
end
