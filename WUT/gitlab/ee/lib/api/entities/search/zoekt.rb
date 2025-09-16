# frozen_string_literal: true

module API
  module Entities
    module Search
      module Zoekt
        class IndexedNamespace < Grape::Entity
          expose :id, documentation: { type: :int, example: 1234 }
          # TODO: migrate away from using shard_id https://gitlab.com/gitlab-org/gitlab/-/issues/429236
          # `zoekt_shard_id` is deprecated use `zoekt_node_id`
          expose :zoekt_shard_id, documentation: { type: :int, example: 1234 } do |_, options|
            options[:zoekt_node_id]
          end
          expose :zoekt_node_id, documentation: { type: :int, example: 1234 } do |_, options|
            options[:zoekt_node_id]
          end
          expose :root_namespace_id, documentation: { type: :int, example: 1234 }, as: :namespace_id
        end

        class Node < Grape::Entity
          expose :id, documentation: { type: :int, example: 1234 }
          expose :index_base_url, documentation: { type: :string, example: 'http://127.0.0.1:6060/' }
          expose :search_base_url, documentation: { type: :string, example: 'http://127.0.0.1:6070/' }
        end

        class ProjectIndexSuccess < Grape::Entity
          expose :job_id do |item|
            item[:job_id]
          end
        end
      end
    end
  end
end
