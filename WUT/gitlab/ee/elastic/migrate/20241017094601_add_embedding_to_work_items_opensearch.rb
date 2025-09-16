# frozen_string_literal: true

class AddEmbeddingToWorkItemsOpensearch < Elastic::Migration
  skip_if -> { !opensearch? }

  def migrate
    Search::Elastic::ReindexingTask.create!(targets: %w[WorkItem], options: { skip_pending_migrations_check: true })
  end

  def completed?
    true
  end
end

private

def opensearch?
  helper.vectors_supported?(:opensearch)
end

def helper
  @helper ||= Gitlab::Elastic::Helper.default
end

AddEmbeddingToWorkItemsOpensearch.prepend ::Search::Elastic::MigrationObsolete
