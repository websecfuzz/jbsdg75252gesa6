# frozen_string_literal: true

class AddRetryVerificationFieldsToProjectRegistry < ActiveRecord::Migration[4.2]
  def change
    add_column :project_registry, :repository_verification_retry_count, :integer
    add_column :project_registry, :wiki_verification_retry_count, :integer
  end
end
