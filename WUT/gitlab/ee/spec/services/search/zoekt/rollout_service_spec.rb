# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Zoekt::RolloutService, feature_category: :global_search do
  let(:logger) { instance_double(Logger, info: nil) }
  let(:resource_pool) do
    instance_double(::Search::Zoekt::SelectionService::ResourcePool,
      enabled_namespaces: enabled_namespaces, nodes: nodes
    )
  end

  let(:plan) { instance_double(::Search::Zoekt::PlanningService::Plan, to_json: '{"plan": "data"}') }
  let(:default_options) do
    {
      num_replicas: 1,
      max_indices_per_replica: Search::Zoekt::MAX_INDICES_PER_REPLICA,
      dry_run: true,
      batch_size: 128,
      logger: logger
    }
  end

  let(:selection_service) { ::Search::Zoekt::SelectionService }
  let(:planning_service) { ::Search::Zoekt::PlanningService }
  let(:provisioning_service) { ::Search::Zoekt::ProvisioningService }
  let(:enabled_namespaces) { ['namespace1'] }
  let(:nodes) { ['node1'] }

  subject(:service) { described_class.new(**options) }

  describe '#execute' do
    subject(:result) { service.execute }

    let(:options) { {} }

    before do
      allow(selection_service).to receive(:execute).with(max_batch_size: default_options[:batch_size])
        .and_return(resource_pool)
    end

    context 'when no enabled namespaces are found' do
      let(:enabled_namespaces) { [] }

      it 'returns a result with empty changes, without re_enqueue and an appropriate message' do
        expect(result.changes).to be_empty
        expect(result.message).to eq('No enabled namespaces found')
        expect(result.re_enqueue).to be false
      end
    end

    context 'when no available nodes are found' do
      let(:nodes) { Search::Zoekt::Node.none }

      it 'returns a result with empty changes, without re_enqueue and an appropriate message' do
        expect(result.changes).to be_empty
        expect(result.message).to eq('No available nodes found')
        expect(result.re_enqueue).to be false
      end
    end

    context 'when dry_run is true' do
      let(:options) { { dry_run: true } }

      before do
        allow(planning_service).to receive(:plan).with(
          enabled_namespaces: enabled_namespaces,
          nodes: nodes,
          num_replicas: default_options[:num_replicas],
          max_indices_per_replica: default_options[:max_indices_per_replica]
        ).and_return(plan)
      end

      it 'returns a result with empty changes, without re_enqueue and an appropriate message' do
        expect(result.changes).to be_empty
        expect(result.message).to eq('Skipping execution of changes because of dry run')
        expect(result.re_enqueue).to be false
      end
    end

    context 'when dry_run is false and provisioning returns errors' do
      let(:options) { { dry_run: false } }
      let(:changes) { { success: [], errors: [{ message: 'Something went wrong' }] } }

      before do
        allow(planning_service).to receive(:plan).with(
          enabled_namespaces: enabled_namespaces,
          nodes: nodes,
          num_replicas: default_options[:num_replicas],
          max_indices_per_replica: default_options[:max_indices_per_replica]
        ).and_return(plan)

        allow(provisioning_service).to receive(:execute).with(plan).and_return(changes)
      end

      it 'returns a failed result, without re_enqueue and with the provisioning error message' do
        expect(result.changes).to match_array({ success: [], errors: [{ message: 'Something went wrong' }] })
        expect(result.message).to eq('Batch is completed with failure')
        expect(result.re_enqueue).to be false
      end
    end

    context 'when dry_run is false and provisioning succeeds' do
      let(:options) do
        { dry_run: false }
      end

      let(:changes) do
        { errors: [], success: [{ namespace_id: 1, replica_id: 1 }] }
      end

      before do
        allow(planning_service).to receive(:plan).with(
          enabled_namespaces: enabled_namespaces,
          nodes: nodes,
          num_replicas: default_options[:num_replicas],
          max_indices_per_replica: default_options[:max_indices_per_replica]
        ).and_return(plan)

        allow(provisioning_service).to receive(:execute).with(plan).and_return(changes)
      end

      it 'returns a successful result, with re_enqueue and an appropriate message' do
        expect(result.changes).to match_array({ success: [{ namespace_id: 1, replica_id: 1 }], errors: [] })
        expect(result.message).to eq('Batch is completed with success')
        expect(result.re_enqueue).to be true
      end
    end

    context 'when dry_run is false and provisioning partially succeeds' do
      let(:options) do
        { dry_run: false }
      end

      let(:changes) { { errors: [{ message: 'Something went wrong' }], success: [{ namespace_id: 1, replica_id: 1 }] } }

      before do
        allow(planning_service).to receive(:plan)
          .with(
            enabled_namespaces: enabled_namespaces,
            nodes: nodes,
            num_replicas: default_options[:num_replicas],
            max_indices_per_replica: default_options[:max_indices_per_replica]
          ).and_return(plan)

        allow(provisioning_service).to receive(:execute).with(plan).and_return(changes)
      end

      it 'returns a result with errors and success, with re_enqueue and an appropriate message' do
        expect(result.changes[:errors]).to eq([{ message: 'Something went wrong' }])
        expect(result.changes[:success]).to match_array([{ namespace_id: 1, replica_id: 1 }])
        expect(result.message).to eq('Batch is completed with partial success')
        expect(result.re_enqueue).to be true
      end
    end

    context 'when dry_run is false and provisioning did not do anything' do
      let(:options) do
        { dry_run: false }
      end

      before do
        allow(planning_service).to receive(:plan).with(
          enabled_namespaces: enabled_namespaces,
          nodes: nodes,
          num_replicas: default_options[:num_replicas],
          max_indices_per_replica: default_options[:max_indices_per_replica]
        ).and_return(plan)

        allow(provisioning_service).to receive(:execute).with(plan).and_return({ errors: [], success: [] })
      end

      it 'returns a result with empty changes, with re_enqueue and an appropriate message' do
        expect(result.changes[:errors]).to be_empty
        expect(result.changes[:success]).to be_empty
        expect(result.message).to eq('Batch is completed without changes')
        expect(result.re_enqueue).to be true
      end
    end
  end

  describe '.execute' do
    let(:options) do
      { dry_run: true }
    end

    it 'delegates to an instance of RolloutService' do
      instance = instance_double(described_class)
      expect(described_class).to receive(:new).with(**options).and_return(instance)
      expect(instance).to receive(:execute)
      described_class.execute(**options)
    end
  end
end
