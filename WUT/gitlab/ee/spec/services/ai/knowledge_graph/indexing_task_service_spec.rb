# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::KnowledgeGraph::IndexingTaskService, feature_category: :knowledge_graph do
  let_it_be_with_reload(:project) { create(:project, :repository) }
  let_it_be(:node) { create(:zoekt_node, :knowledge_graph) }

  describe '#execute' do
    let(:namespace_id) { project.project_namespace.id }
    let(:task_type) { :index_graph_repo }
    let(:use_duo) { [:addon] }

    subject(:result) { described_class.new(namespace_id, task_type).execute }

    shared_examples_for 'failed execution' do
      it 'returns error' do
        expect(result.error?).to be_truthy
      end
    end

    before do
      allow(GitlabSubscriptions::AddOnPurchase).to receive(:for_active_add_ons).and_return(use_duo)
    end

    it 'creates a replica and an indexing task' do
      expect(result.success?).to be_truthy
    end

    context 'when namespace replica already exists' do
      let_it_be(:namespace) { create(:knowledge_graph_enabled_namespace, namespace: project.project_namespace) }
      let_it_be(:replica) { create(:knowledge_graph_replica, knowledge_graph_enabled_namespace: namespace) }

      it 'creates an indexing task' do
        expect(result.success?).to be_truthy
        expect(result.payload[:task].knowledge_graph_replica).to eq(replica)
      end

      context 'when there is already indexing task in pending state for this namespace' do
        let_it_be(:task) { create(:knowledge_graph_task, knowledge_graph_replica: replica) }

        it_behaves_like 'failed execution'
      end
    end

    context "when namespace doesn't exist" do
      let(:namespace_id) { non_existing_record_id }

      it_behaves_like 'failed execution'
    end

    context 'when knowledge_graph_indexing is disabled' do
      before do
        stub_feature_flags(knowledge_graph_indexing: false)
      end

      it_behaves_like 'failed execution'
    end

    context "when project doesn't have repository" do
      let_it_be(:project) { create(:project) }

      it_behaves_like 'failed execution'
    end

    context "when project doesn't have duo features enabled" do
      let(:use_duo) { [] }

      it_behaves_like 'failed execution'
    end

    context 'when ReplicasProvisionService fails to find replica' do
      before do
        allow(::Ai::KnowledgeGraph::ReplicasProvisionService).to receive_message_chain(:new, :execute)
          .and_return(::ServiceResponse.error(message: "some error"))
      end

      it_behaves_like 'failed execution'
    end
  end
end
