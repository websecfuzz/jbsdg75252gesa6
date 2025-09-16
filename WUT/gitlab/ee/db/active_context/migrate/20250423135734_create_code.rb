# frozen_string_literal: true

class CreateCode < ActiveContext::Migration[1.0]
  milestone '18.0'

  # Set number of partitions based on expected number of documents before enabling gem in production
  # https://gitlab.com/gitlab-org/gitlab/-/issues/536216#note_2484267969
  NUMBER_OF_PARTITIONS = 1

  def migrate!
    create_collection :code, number_of_partitions: NUMBER_OF_PARTITIONS, options: { include_ref_fields: false } do |c|
      c.keyword :id
      c.bigint :project_id
      c.keyword :path
      c.smallint :type
      c.text :content
      c.text :name
      c.keyword :source
      c.keyword :language
      c.vector :embeddings_v1, dimensions: 768
    end
  end
end
