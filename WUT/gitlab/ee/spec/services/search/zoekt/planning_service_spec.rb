# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::PlanningService, :freeze_time, feature_category: :global_search do
  let_it_be(:group1) { create(:group) }
  let_it_be(:enabled_namespace1) { create(:zoekt_enabled_namespace, namespace: group1) }
  let_it_be(:group2) { create(:group) }
  let_it_be(:enabled_namespace2) { create(:zoekt_enabled_namespace, namespace: group2) }
  let_it_be(:_) { create_list(:zoekt_node, 5, total_bytes: 100.gigabytes, used_bytes: 90.gigabytes) }
  let_it_be(:nodes) { Search::Zoekt::Node.order_by_unclaimed_space_desc.online }
  let_it_be(:projects_namespace1) do
    [
      create(:project, namespace: group1, statistics: create(:project_statistics, repository_size: 1.gigabyte)),
      create(:project, namespace: group1, statistics: create(:project_statistics, repository_size: 2.gigabytes))
    ]
  end

  let_it_be(:projects_namespace2) do
    [create(:project, namespace: group2, statistics: create(:project_statistics, repository_size: 2.gigabytes))]
  end

  let(:max_indices_per_replica) { Search::Zoekt::MAX_INDICES_PER_REPLICA }

  describe '.plan' do
    subject(:plan) do
      described_class.plan(
        enabled_namespaces: [enabled_namespace1, enabled_namespace2],
        nodes: nodes,
        num_replicas: num_replicas,
        buffer_factor: buffer_factor,
        max_indices_per_replica: max_indices_per_replica
      )
    end

    let(:num_replicas) { 2 }
    let(:buffer_factor) { 1.5 }

    it 'returns total required storage bytes across all namespaces' do
      total_storage = (projects_namespace1 + projects_namespace2).sum { |p| p.statistics.repository_size }
      buffered_storage = total_storage * buffer_factor * num_replicas
      expect(plan[:total_required_storage_bytes]).to eq(buffered_storage)
    end

    it 'returns plans for each enabled namespace' do
      expect(plan[:namespaces].size).to eq(2)
      expect(plan[:namespaces].pluck(:enabled_namespace_id))
        .to contain_exactly(enabled_namespace1.id, enabled_namespace2.id)
    end

    it 'calculates the namespace-specific required storage bytes' do
      namespace1_storage = projects_namespace1.sum { |p| p.statistics.repository_size * buffer_factor }
      namespace2_storage = projects_namespace2.sum { |p| p.statistics.repository_size * buffer_factor }

      expect(plan[:namespaces][0][:namespace_required_storage_bytes]).to eq(namespace1_storage * num_replicas)
      expect(plan[:namespaces][1][:namespace_required_storage_bytes]).to eq(namespace2_storage * num_replicas)
    end

    it 'assigns projects to indices for each namespace without reusing nodes' do
      namespace1_used_nodes = []
      plan[:namespaces][0][:replicas].each do |replica|
        replica[:indices].each do |index|
          expect(namespace1_used_nodes).not_to include(index[:node_id])
          namespace1_used_nodes << index[:node_id]
        end
      end
    end

    context 'when there are no nodes' do
      let_it_be(:nodes) { Search::Zoekt::Node.none }

      it 'creates plan with failure 0 total_required_storage_bytes' do
        expect(plan[:failures]).not_to be_empty
        expect(plan[:namespaces]).to be_empty
      end
    end

    context 'when max indices per replica is reached' do
      let(:max_indices_per_replica) { 1 }

      it 'logs an error for the namespace which can not be fit into 1 index' do
        plan[:failures].each do |namespace_plan|
          expect(namespace_plan[:errors]).to include(a_hash_including(type: :index_limit_exceeded))
        end
      end
    end

    context 'when a namespace has to be spread across multiple indices' do
      let(:buffer_factor) { 2.5 }
      let(:num_replicas) { 1 }

      before do
        create(:project, namespace: group1, statistics: create(:project_statistics, repository_size: 2.gigabytes))
      end

      it 'creates multiple indices for a namespace' do
        namespace1_plan = plan[:namespaces].find { |n| n[:enabled_namespace_id] == enabled_namespace1.id }
        indices_plan = namespace1_plan[:replicas].flat_map { |replica| replica[:indices] }

        expect(indices_plan.size).to eq(2)
        expect(indices_plan.pluck(:node_id).uniq.size).to eq(2)
        projects = indices_plan.first[:projects]
        p_ns = ::Namespace.by_root_id(group1.id).project_namespaces.order(:id)
        expect(projects).to eq({ project_namespace_id_from: nil, project_namespace_id_to: p_ns[1].id })
        first_index_project_namespace_id_to = projects[:project_namespace_id_to]
        projects = indices_plan.last[:projects]
        expect(projects).to eq(
          { project_namespace_id_from: first_index_project_namespace_id_to.next, project_namespace_id_to: nil }
        )

        namespace2_plan = plan[:namespaces].find { |n| n[:enabled_namespace_id] == enabled_namespace2.id }
        indices_plan = namespace2_plan[:replicas].flat_map { |replica| replica[:indices] }
        expect(indices_plan.size).to eq(1)
        projects = indices_plan.first[:projects]
        expect(projects).to eq({ project_namespace_id_from: nil, project_namespace_id_to: nil })
      end
    end

    context 'when there are more projects than the batch size' do
      let(:batch_size) { 2 }
      let(:num_replicas) { 2 }
      let(:buffer_factor) { 1.5 }

      before do
        # Create more projects than the batch size
        (1..6).each do |i|
          create(:project, namespace: group1, statistics: create(:project_statistics, repository_size: i.megabytes))
        end
      end

      it 'processes all projects in batches without skipping any' do
        # Run the planning service with a specific batch size
        result = described_class.plan(
          enabled_namespaces: [enabled_namespace1],
          nodes: nodes,
          num_replicas: num_replicas,
          buffer_factor: buffer_factor
        )

        # Total storage should account for all projects
        total_storage = group1.projects.sum do |p|
          p.statistics.repository_size
        end

        buffered_storage = total_storage * buffer_factor * num_replicas

        expect(result[:total_required_storage_bytes]).to eq(buffered_storage)

        # Ensure all projects are assigned
        assigned_projects = result[:namespaces][0][:replicas].flat_map { |r| r[:indices].flat_map { |i| i[:projects] } }
        lower, upper = assigned_projects.pluck(:project_namespace_id_from, :project_namespace_id_to).flatten.uniq
        id_range = upper.blank? ? lower.. : lower..upper
        project_ids = group1.projects.by_project_namespace(id_range).pluck(:id)

        expect(project_ids).to match_array(group1.projects.pluck(:id))
      end
    end

    context 'when a project has nil statistics' do
      let(:num_replicas) { 1 }
      let(:buffer_factor) { 1.5 }
      let_it_be(:project_with_nil_statistics) { create(:project, namespace: group1) }

      before do
        project_with_nil_statistics.statistics.delete
      end

      it 'skips the project with nil statistics and continues processing other projects' do
        result = described_class.plan(
          enabled_namespaces: [enabled_namespace1],
          nodes: nodes,
          num_replicas: num_replicas,
          buffer_factor: buffer_factor
        )

        expected_storage = projects_namespace1.sum { |p| p.statistics.repository_size * buffer_factor * num_replicas }
        expect(result[:total_required_storage_bytes]).to eq(expected_storage)

        namespace_plan = result[:namespaces].find { |n| n[:namespace_id] == group1.id }
        expect(namespace_plan[:errors]).to be_empty
      end
    end

    context 'when a namespace does not have any project_namespaces' do
      let_it_be(:namespace_without_project_namespace) { create(:group) }
      let_it_be(:enabled_namespace) { create(:zoekt_enabled_namespace, namespace: namespace_without_project_namespace) }

      subject(:plan) do
        described_class.plan(enabled_namespaces: [enabled_namespace], nodes: nodes, num_replicas: num_replicas)
      end

      it 'creates plan with 0 total_required_storage_bytes' do
        expect(plan[:total_required_storage_bytes]).to eq(0)
        expect(plan[:failures]).to be_empty
        projects_plan = plan[:namespaces][0][:replicas][0][:indices][0][:projects]
        expect(projects_plan).to eq({ project_namespace_id_from: nil, project_namespace_id_to: nil })
      end

      context 'when node is not available' do
        let_it_be(:nodes) { Search::Zoekt::Node.none }

        it 'creates plan with failure 0 total_required_storage_bytes' do
          expect(plan[:failures]).not_to be_empty
          expect(plan[:namespaces]).to be_empty
        end
      end
    end
  end
end
