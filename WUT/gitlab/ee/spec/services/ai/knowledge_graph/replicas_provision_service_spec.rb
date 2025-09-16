# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::KnowledgeGraph::ReplicasProvisionService, feature_category: :knowledge_graph do
  let_it_be(:namespace) { create(:project_namespace) }
  let_it_be(:node1) { create(:zoekt_node, :knowledge_graph, total_bytes: 10.gigabytes) }
  let_it_be(:node2) { create(:zoekt_node, :knowledge_graph, total_bytes: 20.gigabytes) }
  let_it_be(:node3) { create(:zoekt_node, :knowledge_graph, total_bytes: 30.gigabytes) }

  describe '#execute' do
    let(:replica_count) { 2 }

    subject(:result) { described_class.new(namespace, replica_count: replica_count).execute }

    it 'creates required number of replicas for the namespace' do
      expect(result.success?).to be_truthy
      expect(namespace.knowledge_graph_enabled_namespace.replicas.pluck(:zoekt_node_id))
        .to match_array([node3.id, node2.id])
    end

    context 'when there is already a replica for the namespace' do
      let_it_be(:enabled_namespace) { create(:knowledge_graph_enabled_namespace, namespace: namespace) }
      let_it_be(:replica) do
        create(:knowledge_graph_replica, knowledge_graph_enabled_namespace: enabled_namespace, zoekt_node: node3)
      end

      it 'creates uses other nodes to create replicas' do
        expect(result.success?).to be_truthy
        expect(namespace.knowledge_graph_enabled_namespace.replicas.pluck(:zoekt_node_id))
          .to match_array([node3.id, node2.id, node1.id])
      end
    end

    shared_examples_for 'failed execution' do
      it 'returns error' do
        expect(result.error?).to be_truthy
      end
    end

    context "when namespace doesn't exist" do
      let(:namespace) { nil }

      it_behaves_like 'failed execution'
    end

    context 'when there are not enough nodes for new replicas' do
      let(:replica_count) { 4 }

      it_behaves_like 'failed execution'
    end
  end
end
