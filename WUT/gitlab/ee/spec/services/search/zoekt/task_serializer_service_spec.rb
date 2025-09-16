# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Zoekt::TaskSerializerService, feature_category: :global_search do
  let_it_be(:node) { create(:zoekt_node) }
  let_it_be(:task) { create(:zoekt_task, node: node) }

  let(:service) { described_class.new(task, node) }

  subject(:execute_task) { service.execute }

  describe '.execute' do
    it 'passes arguments to new and calls execute' do
      expect(described_class).to receive(:new).with(task, node).and_return(service)
      expect(service).to receive(:execute)

      described_class.execute(task, node)
    end
  end

  describe '#execute' do
    let(:project) { task.zoekt_repository.project }

    before do
      allow(project).to receive(:archived?).and_return(true)
    end

    it 'serializes the task' do
      expect(execute_task[:name]).to eq(:index)
      expect(execute_task[:payload].keys).to contain_exactly(
        :GitalyConnectionInfo,
        :Callback,
        :RepoId,
        :FileSizeLimit,
        :Timeout,
        :Parallelism,
        :FileCountLimit,
        :Metadata
      )

      meta = execute_task[:payload][:Metadata]
      expect(meta[:traversal_ids]).to eq(project.namespace_ancestry)
      expect(meta[:visibility_level]).to eq(project.visibility_level.to_s)
      expect(meta[:repository_access_level]).to eq(project.repository_access_level.to_s)
      expect(meta[:forked]).to eq("f")
      expect(meta[:archived]).to eq("t")
    end

    context 'when local socket is used' do
      let(:connection_data) { { "address" => "unix:gdk-ee/praefect.socket", "token" => nil } }

      before do
        allow(Gitlab::GitalyClient).to receive(:connection_data).and_return(connection_data)
      end

      it 'transforms unix socket' do
        expected_path = "unix:#{Rails.root.join('gdk-ee/praefect.socket')}"
        expect(execute_task[:payload][:GitalyConnectionInfo][:Address]).to eq(expected_path)
      end
    end

    context 'with :force_index_repo task' do
      let(:task) { create(:zoekt_task, task_type: :force_index_repo) }

      it 'serializes the task' do
        expect(execute_task[:name]).to eq(:index)
        expect(execute_task[:payload].keys).to contain_exactly(
          :GitalyConnectionInfo,
          :Callback,
          :RepoId,
          :FileSizeLimit,
          :Timeout,
          :Force,
          :Parallelism,
          :FileCountLimit,
          :Metadata
        )
      end
    end

    context 'with :delete_repo task' do
      let(:task) { create(:zoekt_task, task_type: :delete_repo) }

      it 'serializes the task' do
        expect(execute_task[:name]).to eq(:delete)
        expect(execute_task[:payload].keys).to contain_exactly(:RepoId, :Callback)
        expect(execute_task[:payload][:RepoId]).to eq(task.project_identifier)
      end
    end

    context 'with :index_graph_repo task' do
      let(:project) { task.knowledge_graph_replica.knowledge_graph_enabled_namespace.namespace.project }
      let(:task) { create(:knowledge_graph_task, task_type: :index_graph_repo) }

      it 'serializes the task' do
        expect(execute_task).to match(a_hash_including(
          name: :index_graph,
          payload: {
            GitalyConnectionInfo: an_instance_of(Hash),
            Callback: {
              name: 'index_graph',
              payload: { task_id: task.id, service_type: :knowledge_graph }
            },
            RepoId: project.id,
            NamespaceId: project.project_namespace.id,
            Timeout: "5400s"
          }
        ))
      end
    end

    context 'with unknown task' do
      let(:task) { create(:zoekt_task) }

      before do
        allow(task).to receive(:task_type).and_return(:unknown)
      end

      it 'raises an exception' do
        expect { execute_task }.to raise_error(ArgumentError)
      end
    end
  end
end
