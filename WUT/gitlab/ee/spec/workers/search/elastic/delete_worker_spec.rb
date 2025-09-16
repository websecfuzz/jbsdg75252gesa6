# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::DeleteWorker, :elastic_helpers, feature_category: :global_search do
  describe '#perform' do
    subject(:perform) do
      described_class.new.perform({ task: :delete_project_associations })
    end

    context 'when Elasticsearch is disabled' do
      before do
        stub_ee_application_setting(elasticsearch_indexing: false)
      end

      it 'does not do anything' do
        expect(perform).to be_falsey
      end
    end

    context 'when Elasticsearch is enabled' do
      before do
        stub_ee_application_setting(elasticsearch_indexing: true)
      end

      context 'when we pass :all' do
        it 'queues all tasks' do
          Search::Elastic::DeleteWorker::TASKS.each_key do |t|
            expect(described_class).to receive(:perform_async).with({
              task: t
            })
          end
          described_class.new.perform({ task: :all })
        end
      end

      context 'when we pass valid task' do
        context 'with delete_project_work_items task' do
          subject(:perform) do
            described_class.new.perform({ task: :delete_project_work_items })
          end

          it 'calls the corresponding service' do
            expect(::Search::Elastic::Delete::ProjectWorkItemsService).to receive(:execute)
            perform
          end
        end

        context 'with delete_project_vulnerabilities task' do
          subject(:perform) do
            described_class.new.perform({ task: :delete_project_vulnerabilities })
          end

          it 'calls the corresponding service' do
            expect(::Search::Elastic::Delete::VulnerabilityService).to receive(:execute)
            perform
          end
        end
      end

      context 'when we pass invalid task' do
        it 'raises ArgumentError' do
          expect { described_class.new.perform({ task: :unknown_task }) }.to raise_error(ArgumentError)
        end
      end
    end
  end
end
