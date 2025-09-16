# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::KnowledgeGraph::Replica, feature_category: :knowledge_graph do
  describe 'relations' do
    it { is_expected.to belong_to(:zoekt_node).inverse_of(:knowledge_graph_replicas) }
    it { is_expected.to belong_to(:knowledge_graph_enabled_namespace).inverse_of(:replicas) }
  end

  it_behaves_like 'cleanup by a loose foreign key' do
    let!(:model) { create(:knowledge_graph_replica) }
    let!(:parent) { model.knowledge_graph_enabled_namespace }
  end

  describe 'validations' do
    let_it_be(:namespace) { create(:knowledge_graph_enabled_namespace) }

    subject(:replica) { create(:knowledge_graph_replica, knowledge_graph_enabled_namespace: namespace) }

    specify do
      expect(replica).to validate_uniqueness_of(:knowledge_graph_enabled_namespace_id)
        .scoped_to(:zoekt_node_id).allow_nil
    end

    it 'sets namespace_id from associated enabled_namespace' do
      replica.namespace_id = nil

      expect(replica).to be_valid
      expect(replica.namespace_id).to eq(namespace.namespace_id)
    end

    it 'validates if namespace_id equals enabled_namespace.namespace_id' do
      expect(replica).to be_valid

      replica.namespace_id = namespace.namespace_id.next

      expect(replica).not_to be_valid
    end
  end
end
