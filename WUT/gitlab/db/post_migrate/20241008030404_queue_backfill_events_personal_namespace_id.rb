# frozen_string_literal: true

class QueueBackfillEventsPersonalNamespaceId < Gitlab::Database::Migration[2.2]
  milestone '17.5'

  restrict_gitlab_migration gitlab_schema: :gitlab_main

  MIGRATION = 'BackfillEventsShardingKey'
  DELAY_INTERVAL = 2.minutes
  BATCH_SIZE = 5000
  SUB_BATCH_SIZE = 150

  def up
    queue_batched_background_migration(
      MIGRATION,
      :events,
      :id,
      job_interval: DELAY_INTERVAL,
      batch_size: BATCH_SIZE,
      sub_batch_size: SUB_BATCH_SIZE
    )
  end

  def down
    delete_batched_background_migration(MIGRATION, :events, :id, [])
  end
end
