# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Zoekt::TaskPresenterService, feature_category: :global_search do
  let_it_be(:node) { create(:zoekt_node) }
  let_it_be_with_reload(:project) { create(:project, :repository) }
  let_it_be(:task) { create(:zoekt_task, node: node, project: project) }
  let_it_be(:delete_task) { create(:zoekt_task, node: node, task_type: :delete_repo) }

  let_it_be_with_reload(:enabled_namespace) do
    create(:knowledge_graph_enabled_namespace, namespace: project.project_namespace)
  end

  let_it_be_with_reload(:replica) do
    create(:knowledge_graph_replica, knowledge_graph_enabled_namespace: enabled_namespace)
  end

  let_it_be_with_reload(:graph_task) { create(:knowledge_graph_task, node: node, knowledge_graph_replica: replica) }
  let_it_be_with_reload(:delete_graph_task) { create(:knowledge_graph_task, node: node, task_type: :delete_graph_repo) }

  let(:service) { described_class.new(node) }

  subject(:execute_task) { service.execute }

  describe '.execute' do
    it 'passes arguments to new and calls execute' do
      expect(described_class).to receive(:new).with(node).and_return(service)
      expect(service).to receive(:execute)

      described_class.execute(node)
    end
  end

  describe '#execute' do
    context 'when application setting zoekt_indexing_paused is true' do
      before do
        stub_ee_application_setting(zoekt_indexing_paused: true)
      end

      it 'excludes zoekt tasks' do
        expect(execute_task).to eq([
          ::Search::Zoekt::TaskSerializerService.execute(graph_task, node),
          ::Search::Zoekt::TaskSerializerService.execute(delete_graph_task, node)
        ])
      end

      context 'when knowledge graph indexing is disabled' do
        before do
          stub_feature_flags(knowledge_graph_indexing: false)
        end

        it "returns only deletion tasks" do
          expect(execute_task)
            .to contain_exactly(::Search::Zoekt::TaskSerializerService.execute(delete_graph_task, node))
        end
      end
    end

    context 'when application setting zoekt_indexing_paused is false' do
      before do
        stub_ee_application_setting(zoekt_indexing_paused: false)
      end

      it 'returns both zoekt and knowledge graph serialized tasks' do
        expect(execute_task).to eq([
          ::Search::Zoekt::TaskSerializerService.execute(graph_task, node),
          ::Search::Zoekt::TaskSerializerService.execute(delete_graph_task, node),
          ::Search::Zoekt::TaskSerializerService.execute(task, node),
          ::Search::Zoekt::TaskSerializerService.execute(delete_task, node)
        ])
      end

      context 'when knowledge graph indexing is disabled' do
        before do
          stub_feature_flags(knowledge_graph_indexing: false)
        end

        it 'excludes knowledge graph tasks except deletion tasks' do
          expect(execute_task).to eq([
            ::Search::Zoekt::TaskSerializerService.execute(delete_graph_task, node),
            ::Search::Zoekt::TaskSerializerService.execute(task, node),
            ::Search::Zoekt::TaskSerializerService.execute(delete_task, node)
          ])
        end
      end

      context "when concurrency limit is lower than all tasks" do
        before do
          allow(node).to receive(:concurrency_limit).and_return(3)
        end

        it "returns a subset of zoekt and knowledge graph tasks" do
          expect(execute_task).to eq([
            ::Search::Zoekt::TaskSerializerService.execute(graph_task, node),
            ::Search::Zoekt::TaskSerializerService.execute(task, node),
            ::Search::Zoekt::TaskSerializerService.execute(delete_task, node)
          ])
        end
      end
    end

    context 'when critical storage watermark is exceeded' do
      it 'only presents delete repo tasks' do
        expect(node).to receive(:watermark_exceeded_critical?).and_return(true)
        expect(execute_task).to eq([
          ::Search::Zoekt::TaskSerializerService.execute(delete_graph_task, node),
          ::Search::Zoekt::TaskSerializerService.execute(delete_task, node)
        ])
      end
    end
  end
end
