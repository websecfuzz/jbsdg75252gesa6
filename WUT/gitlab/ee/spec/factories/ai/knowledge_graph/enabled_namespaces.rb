# frozen_string_literal: true

FactoryBot.define do
  factory :knowledge_graph_enabled_namespace, class: '::Ai::KnowledgeGraph::EnabledNamespace' do
    namespace { association(:project_namespace) }
  end
end
