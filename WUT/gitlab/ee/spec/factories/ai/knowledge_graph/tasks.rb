# frozen_string_literal: true

FactoryBot.define do
  factory :knowledge_graph_task, class: '::Ai::KnowledgeGraph::Task' do
    knowledge_graph_replica { association(:knowledge_graph_replica) }
    node { association(:zoekt_node) }
    namespace_id { knowledge_graph_replica.namespace_id }
    task_type { :index_graph_repo }
    retries_left { 3 }
  end
end
