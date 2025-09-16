# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ElasticClusterReindexingCronWorker, feature_category: :global_search do
  subject(:worker) { described_class.new }

  it_behaves_like 'an idempotent worker' do
    describe '#perform' do
      before do
        stub_ee_application_setting(elasticsearch_indexing: true)
      end

      it 'calls execute method' do
        expect(Search::Elastic::ReindexingTask).to receive(:current).and_return(build(:elastic_reindexing_task))

        expect_next_instance_of(::Search::Elastic::ClusterReindexingService) do |service|
          expect(service).to receive(:execute).and_return(false)
        end

        worker.perform
      end

      context 'when elasticsearch_indexing is false' do
        before do
          stub_ee_application_setting(elasticsearch_indexing: false)
        end

        it 'calls does nothing' do
          expect(Search::Elastic::ReindexingTask).not_to receive(:current)
          expect(Search::Elastic::ReindexingTask).not_to receive(:drop_old_indices!)

          expect(worker.perform).to be(false)
        end
      end

      it 'removes old indices if no task is found' do
        expect(Search::Elastic::ReindexingTask).to receive(:current).and_return(nil)
        expect(Search::Elastic::ReindexingTask).to receive(:drop_old_indices!)

        expect(worker.perform).to be(false)
      end
    end
  end
end
