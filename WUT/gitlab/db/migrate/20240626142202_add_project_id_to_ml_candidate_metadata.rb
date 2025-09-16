# frozen_string_literal: true

class AddProjectIdToMlCandidateMetadata < Gitlab::Database::Migration[2.2]
  milestone '17.2'

  def change
    add_column :ml_candidate_metadata, :project_id, :bigint
  end
end
