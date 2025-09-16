# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::KnowledgeGraph::IndexingTaskWorker, type: :worker, feature_category: :knowledge_graph do
  it_behaves_like 'worker with data consistency', described_class, data_consistency: :delayed

  describe '#perform' do
    let_it_be(:namespace) { create(:project_namespace) }
    let(:job_args) { [namespace.id, 'index_repo'] }

    subject(:perform_worker) { described_class.new.perform(*job_args) }

    it_behaves_like 'an idempotent worker' do
      it 'calls the IndexingTaskService service' do
        expect(Ai::KnowledgeGraph::IndexingTaskService).to receive(:new)
          .with(namespace.id, 'index_repo')
          .and_return(instance_double(
            Ai::KnowledgeGraph::IndexingTaskService, execute: ::ServiceResponse.success))

        perform_worker
      end

      it 'logs an error if IndexingTaskService fails' do
        allow(Ai::KnowledgeGraph::IndexingTaskService).to receive(:new)
          .with(namespace.id, 'index_repo')
          .and_return(instance_double(
            Ai::KnowledgeGraph::IndexingTaskService, execute: ::ServiceResponse.error(message: "some error")))

        expect(Sidekiq.logger).to receive(:error).with(hash_including("message" => "some error"))

        perform_worker
      end
    end
  end
end
