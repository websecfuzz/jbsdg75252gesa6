# frozen_string_literal: true

class SetCodeSearchVersion < ActiveContext::Migration[1.0]
  milestone '18.0'

  def migrate!
    update_collection_metadata(collection: collection, metadata: metadata)
  end

  def metadata
    { search_embedding_version: 1 }
  end

  def collection
    Ai::ActiveContext::Collections::Code
  end
end
