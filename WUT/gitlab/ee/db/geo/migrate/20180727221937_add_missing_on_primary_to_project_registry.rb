# frozen_string_literal: true

class AddMissingOnPrimaryToProjectRegistry < ActiveRecord::Migration[4.2]
  def change
    add_column :project_registry, :repository_missing_on_primary, :boolean
    add_column :project_registry, :wiki_missing_on_primary, :boolean
  end
end
