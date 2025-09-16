# frozen_string_literal: true

require 'spec_helper'
require_migration!

RSpec.describe QueueBackfillPCiPipelineVariablesProjectId, migration: :gitlab_ci, feature_category: :continuous_integration do
  let!(:batched_migration) { described_class::MIGRATION }

  it 'schedules a new batched migration' do
    reversible_migration do |migration|
      migration.before -> {
        expect(batched_migration).not_to have_scheduled_batched_migration
      }

      migration.after -> {
        expect(batched_migration).to have_scheduled_batched_migration(
          table_name: :p_ci_pipeline_variables,
          column_name: :id,
          interval: described_class::DELAY_INTERVAL,
          batch_size: described_class::BATCH_SIZE,
          sub_batch_size: described_class::SUB_BATCH_SIZE,
          gitlab_schema: :gitlab_ci,
          job_arguments: [
            :project_id,
            :p_ci_pipelines,
            :project_id,
            :pipeline_id,
            :partition_id
          ]
        )
      }
    end
  end

  context 'when executed on .com' do
    before do
      allow(Gitlab).to receive(:com_except_jh?).and_return(true)
    end

    it 'schedules a new batched migration' do
      reversible_migration do |migration|
        migration.before -> {
          expect(batched_migration).not_to have_scheduled_batched_migration
        }

        migration.after -> {
          expect(batched_migration).to have_scheduled_batched_migration(
            table_name: :p_ci_pipeline_variables,
            column_name: :id,
            interval: described_class::DELAY_INTERVAL,
            batch_size: described_class::GITLAB_OPTIMIZED_BATCH_SIZE,
            sub_batch_size: described_class::GITLAB_OPTIMIZED_SUB_BATCH_SIZE,
            gitlab_schema: :gitlab_ci,
            job_arguments: [
              :project_id,
              :p_ci_pipelines,
              :project_id,
              :pipeline_id,
              :partition_id
            ]
          )
        }
      end
    end
  end
end
