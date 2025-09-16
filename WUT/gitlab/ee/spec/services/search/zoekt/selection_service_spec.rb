# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::SelectionService, feature_category: :global_search do
  describe '.execute' do
    subject(:resource_pool) { described_class.execute }

    let_it_be(:_) { create(:application_setting) }
    let_it_be(:ns_1) { create(:group) }
    let_it_be(:ns_2) { create(:group) }

    context 'with basic resource pool structure' do
      it 'returns a resource pool responding to :enabled_namespaces and :nodes' do
        expect(resource_pool).to respond_to(:enabled_namespaces)
        expect(resource_pool).to respond_to(:nodes)
      end
    end

    context 'with enabled namespaces selection' do
      let_it_be(:eligible_namespace) { create(:zoekt_enabled_namespace, namespace: ns_1) }
      let_it_be(:ineligible_namespace) { create(:zoekt_enabled_namespace, namespace: ns_2) }
      let_it_be(:ns_3) { create(:group) }
      let_it_be(:ineligible_namespace2) do
        create(:zoekt_enabled_namespace, namespace: ns_3, last_rollout_failed_at: Time.current.iso8601)
      end

      let_it_be(:ns_4) { create(:group) }
      let_it_be(:eligible_namespace2) do
        create(:zoekt_enabled_namespace, namespace: ns_4, last_rollout_failed_at: 2.days.ago.iso8601)
      end

      before do
        # For the eligible namespace, the project count will be low (default).
        # For the ineligible namespace, stub its associated namespace so that
        # project_namespaces.count returns more than MAX_PROJECTS_PER_NAMESPACE
        allow(::Namespace).to receive(:by_root_id)
          .with(eligible_namespace.root_namespace_id)
          .and_return(::Namespace.where(id: eligible_namespace.root_namespace_id))

        allow(::Namespace).to receive(:by_root_id)
          .with(eligible_namespace2.root_namespace_id)
          .and_return(::Namespace.where(id: eligible_namespace2.root_namespace_id))

        allow(::Namespace).to receive(:by_root_id)
          .with(ineligible_namespace.root_namespace_id)
          .and_return(::Namespace.where(id: ineligible_namespace.root_namespace_id))

        allow(ineligible_namespace.namespace)
          .to receive_message_chain(:project_namespaces, :count)
          .and_return(described_class::MAX_PROJECTS_PER_NAMESPACE.next)

        allow(::Namespace).to receive(:by_root_id)
          .with(ineligible_namespace.root_namespace_id)
          .and_return(ineligible_namespace.namespace.root_ancestor)
      end

      # eligible namespaces are for which last_rollout_failed_at is nil or older than zoekt_rollout_retry_interval
      # project_count is less than the MAX_PROJECTS_PER_NAMESPACE
      it 'includes all eligible namespaces' do
        expect(resource_pool.enabled_namespaces).to include(eligible_namespace)
        expect(resource_pool.enabled_namespaces).not_to include(ineligible_namespace, ineligible_namespace2)
      end

      it 'excludes namespaces with rollout blocked flag' do
        # Verify that the with_rollout_allowed scope is being applied
        expect(Search::Zoekt::EnabledNamespace).to receive(:with_rollout_allowed).and_call_original

        # Verify that the namespace with last_rollout_failed_at is excluded
        result = described_class.execute
        expect(result.enabled_namespaces).not_to include(ineligible_namespace2)
      end

      context 'when testing specific scopes' do
        it 'with_rollout_blocked scope finds namespaces with last_rollout_failed_at' do
          namespaces = Search::Zoekt::EnabledNamespace.with_rollout_blocked
          expect(namespaces).to include(ineligible_namespace2)
          expect(namespaces).not_to include(eligible_namespace, ineligible_namespace)
        end

        it 'with_rollout_allowed scope finds namespaces without last_rollout_failed_at' do
          namespaces = Search::Zoekt::EnabledNamespace.with_rollout_allowed
          expect(namespaces).to include(eligible_namespace, ineligible_namespace)
          expect(namespaces).not_to include(ineligible_namespace2)
        end
      end
    end

    context 'with max batch size enforcement' do
      let(:max_batch_size) { 2 }

      subject(:resource_pool) { described_class.new(max_batch_size: max_batch_size).execute }

      before do
        # Create more eligible namespaces than the max batch size.
        create_list(:zoekt_enabled_namespace, 3)
      end

      it 'limits the number of selected namespaces to the max batch size' do
        expect(resource_pool.enabled_namespaces.size).to eq(max_batch_size)
      end
    end

    context 'with available nodes selection' do
      let_it_be(:eligible_node) { create(:zoekt_node, :enough_free_space) }
      let_it_be(:eligible_node2) { create(:zoekt_node, :not_enough_free_space) }
      let_it_be(:offline_node) { create(:zoekt_node, :offline, :enough_free_space) }
      # Node with no unclaimed storage.
      let_it_be(:no_storage_node) { create(:zoekt_node, total_bytes: 100.gigabytes, used_bytes: 100.gigabytes) }
      let_it_be(:graph_node) { create(:zoekt_node, services: [::Search::Zoekt::Node::SERVICES[:knowledge_graph]]) }

      it 'returns only online zoekt nodes with positive unclaimed storage ordered by unclaimed_storage_bytes' do
        expect(resource_pool.nodes.to_a).to eq([eligible_node, eligible_node2])
        expect(resource_pool.nodes).not_to include(no_storage_node, offline_node, graph_node)
      end
    end

    context 'when no eligible namespaces exist' do
      before do
        # Create namespaces but stub each so that project_namespaces.count returns more than MAX_PROJECTS_PER_NAMESPACE.
        create_list(:zoekt_enabled_namespace, 2).each do |ns|
          allow(ns.namespace.root_ancestor)
            .to receive_message_chain(:project_namespaces, :count)
            .and_return(described_class::MAX_PROJECTS_PER_NAMESPACE.next)
          allow(::Namespace).to receive(:by_root_id)
            .with(ns.root_namespace_id)
            .and_return(ns.namespace.root_ancestor)
        end
      end

      it 'returns an empty array for namespaces' do
        expect(resource_pool.enabled_namespaces).to be_empty
      end
    end

    context 'when no eligible nodes exist' do
      before do
        Search::Zoekt::Node.update_all(last_seen_at: (Search::Zoekt::Node::ONLINE_DURATION_THRESHOLD + 1.minute).ago)
      end

      it 'returns an empty array for nodes' do
        expect(resource_pool.nodes).to eq([])
      end
    end
  end
end
