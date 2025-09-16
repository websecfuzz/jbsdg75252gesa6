# frozen_string_literal: true

class FkCiJobsArtifactsCiBuildTraceMetadata < Gitlab::Database::Migration[2.2]
  include Gitlab::Database::PartitioningMigrationHelpers

  disable_ddl_transaction!
  milestone '17.4'

  def up
    add_concurrent_partitioned_foreign_key(
      :p_ci_build_trace_metadata, :p_ci_job_artifacts,
      name: :fk_21d25cac1a_p,
      column: [:partition_id, :trace_artifact_id],
      target_column: [:partition_id, :id],
      on_update: :cascade,
      on_delete: :cascade,
      reverse_lock_order: true
    )
  end

  def down
    with_lock_retries do
      remove_foreign_key_if_exists :p_ci_build_trace_metadata, :p_ci_job_artifacts,
        name: :fk_21d25cac1a_p, reverse_lock_order: true
    end
  end
end
