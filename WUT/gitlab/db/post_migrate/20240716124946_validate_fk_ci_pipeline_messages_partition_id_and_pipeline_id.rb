# frozen_string_literal: true

class ValidateFkCiPipelineMessagesPartitionIdAndPipelineId < Gitlab::Database::Migration[2.2]
  milestone '17.3'

  TABLE_NAME = :ci_pipeline_messages
  FK_NAME = :fk_rails_8d3b04e3e1_p
  COLUMNS = [:partition_id, :pipeline_id]

  def up
    validate_foreign_key(TABLE_NAME, COLUMNS, name: FK_NAME)
  end

  def down
    # no-op
  end
end
