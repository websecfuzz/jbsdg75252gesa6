# frozen_string_literal: true

class AddDestinationFkToAuditEventsInstanceNamespaceFilters < Gitlab::Database::Migration[2.2]
  milestone '17.0'

  disable_ddl_transaction!

  def up
    add_concurrent_foreign_key :audit_events_streaming_instance_namespace_filters,
      :audit_events_instance_external_streaming_destinations,
      column: :external_streaming_destination_id,
      on_delete: :cascade
  end

  def down
    with_lock_retries do
      remove_foreign_key_if_exists :audit_events_streaming_http_instance_namespace_filters,
        column: :external_streaming_destination_id
    end
  end
end
