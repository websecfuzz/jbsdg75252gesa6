# frozen_string_literal: true

FactoryBot.define do
  factory :knowledge_graph_replica, class: '::Ai::KnowledgeGraph::Replica' do
    knowledge_graph_enabled_namespace { association(:knowledge_graph_enabled_namespace) }
    zoekt_node { association(:zoekt_node) }
    retries_left { 3 }
  end
end
