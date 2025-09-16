# frozen_string_literal: true

class RemoveEmbedding0FromWorkItems < Elastic::Migration
  include ::Search::Elastic::MigrationRemoveFieldsHelper

  skip_if -> { !Gitlab::Saas.feature_available?(:ai_vertex_embeddings) }

  batched!
  throttle_delay 1.minute

  private

  def index_name
    ::Search::Elastic::References::WorkItem.index
  end

  def document_type
    'work_item'
  end

  def field_to_remove
    'embedding_0'
  end
end
