# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Zoekt::Node, feature_category: :global_search do
  let_it_be_with_reload(:node) do
    create(:zoekt_node, index_base_url: 'http://example.com:1234/', search_base_url: 'http://example.com:4567/')
  end

  let_it_be(:indexed_namespace1) { create(:namespace) }
  let_it_be(:indexed_namespace2) { create(:namespace) }
  let_it_be(:unindexed_namespace) { create(:namespace) }
  let_it_be(:enabled_namespace1) { create(:zoekt_enabled_namespace, namespace: indexed_namespace1) }
  let_it_be(:zoekt_index) { create(:zoekt_index, :ready, node: node, zoekt_enabled_namespace: enabled_namespace1) }

  before do
    enabled_namespace2 = create(:zoekt_enabled_namespace, namespace: indexed_namespace2)
    create(:zoekt_index, :ready, node: node, zoekt_enabled_namespace: enabled_namespace2)
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:index_base_url) }
    it { is_expected.to validate_presence_of(:search_base_url) }
    it { is_expected.to validate_presence_of(:uuid) }
    it { is_expected.to validate_presence_of(:last_seen_at) }
    it { is_expected.to validate_presence_of(:indexed_bytes) }
    it { is_expected.to validate_presence_of(:used_bytes) }
    it { is_expected.to validate_presence_of(:total_bytes) }
    it { is_expected.to validate_presence_of(:usable_storage_bytes) }
    it { is_expected.to validate_presence_of(:schema_version) }
    it { is_expected.to validate_uniqueness_of(:uuid).case_insensitive }

    describe 'metadata JSON schema validation' do
      it 'allows null values in version field' do
        node = build(:zoekt_node)
        node.metadata['version'] = nil

        expect(node).to be_valid
      end
    end

    describe 'valid_services' do
      using RSpec::Parameterized::TableSyntax

      where(:services, :is_valid) do
        []        | false
        nil       | false
        [:foo]    | false
        [0, :foo] | false
        [0, 10]   | false
        [0]       | true
        [0, 1]    | true
      end

      with_them do
        it 'validates services array' do
          node = build(:zoekt_node, services: services)

          expect(node.valid?).to eq(is_valid)
        end
      end
    end
  end

  describe 'relations' do
    it { is_expected.to have_many(:indices).inverse_of(:node) }
    it { is_expected.to have_many(:tasks).inverse_of(:node) }
    it { is_expected.to have_many(:enabled_namespaces).through(:indices) }
    it { is_expected.to have_many(:zoekt_repositories).through(:indices) }
    it { is_expected.to have_many(:knowledge_graph_replicas) }
  end

  describe 'scopes' do
    describe '.lost', :freeze_time do
      let_it_be(:offline_node) { create(:zoekt_node, last_seen_at: 10.minutes.ago) }
      let_it_be(:lost_node) { create(:zoekt_node, :lost) }

      context 'when there is lost node threshold' do
        before do
          allow(::Search::Zoekt::Settings).to receive(:lost_node_threshold).and_return(30.minutes)
        end

        it 'returns all the lost nodes' do
          expect(described_class.lost).to contain_exactly(lost_node)
        end
      end

      context 'when there is no node threshold' do
        before do
          allow(::Search::Zoekt::Settings).to receive(:lost_node_threshold).and_return(nil)
        end

        it 'returns all the lost nodes' do
          expect(described_class.lost).to be_empty
        end
      end
    end

    describe '.with_pending_indices' do
      let_it_be(:node_with_pending_indices) { create(:zoekt_node) }
      let_it_be(:node_without_pending_indices) { create(:zoekt_node) }
      let_it_be(:node_with_ready_indices) { create(:zoekt_node) }

      before do
        create(:zoekt_index, state: :pending, node: node_with_pending_indices)
        create(:zoekt_index, state: :ready, node: node_with_ready_indices)
      end

      it 'returns only nodes that have pending indices' do
        expect(described_class.with_pending_indices).to contain_exactly(node_with_pending_indices)
      end

      it 'does not include nodes without pending indices' do
        expect(described_class.with_pending_indices).not_to include(node_without_pending_indices)
        expect(described_class.with_pending_indices).not_to include(node_with_ready_indices)
      end
    end

    describe '.online', :freeze_time do
      let_it_be(:online_node) { create(:zoekt_node) }
      let_it_be(:offline_node) { create(:zoekt_node, :offline) }

      it 'returns nodes considered to be online' do
        expect(described_class.online).to contain_exactly(node, online_node)
      end
    end

    describe '.searchable', :freeze_time do
      let_it_be(:searchable_node) { create(:zoekt_node) }
      let_it_be(:non_searchable_node) { create(:zoekt_node, :offline) }

      it 'returns nodes considered to be searchable' do
        expect(described_class.searchable).to include searchable_node
        expect(described_class.searchable).not_to include non_searchable_node
      end
    end

    describe '.by_name' do
      let_it_be(:node1) { create(:zoekt_node, metadata: { name: 'node1' }) }
      let_it_be(:node2) { create(:zoekt_node, metadata: { name: 'node2' }) }
      let_it_be(:node3) { create(:zoekt_node, metadata: { name: 'node3' }) }

      it 'returns nodes filtered by name' do
        expect(described_class.by_name('node1')).to contain_exactly(node1)
        expect(described_class.by_name('node1', 'node2')).to contain_exactly(node1, node2)
        expect(described_class.by_name('non_existent')).to be_empty
      end
    end

    describe '.searchable_for_project' do
      let_it_be(:project) { create(:project, namespace: indexed_namespace1) }
      let_it_be(:zoekt_index) { create(:zoekt_index) }

      context 'when zoekt_repository for the given project does not exists' do
        it 'is empty' do
          expect(described_class.searchable_for_project(project)).to be_empty
        end
      end

      context 'when zoekt_repository for the given project exists' do
        let_it_be_with_reload(:zoekt_repository) do
          create(:zoekt_repository, project: project, zoekt_index: zoekt_index)
        end

        context 'when there is no ready repository' do
          it 'is empty' do
            expect(described_class.searchable_for_project(project)).to be_empty
          end
        end

        context 'when there is a ready repository' do
          before do
            zoekt_repository.ready!
          end

          it 'returns the nodes' do
            expect(described_class.searchable_for_project(project)).not_to be_empty
          end

          context 'when there is no online nodes' do
            before do
              Search::Zoekt::Node.update_all(last_seen_at: Search::Zoekt::Node::ONLINE_DURATION_THRESHOLD.ago - 1.hour)
            end

            it 'is empty' do
              expect(described_class.searchable_for_project(project)).to be_empty
            end
          end
        end
      end

      describe '.available_for_knowledge_graph_namespace' do
        let_it_be(:node_no_kg) { create(:zoekt_node) }
        let_it_be(:node_kg1) { create(:zoekt_node, :knowledge_graph) }
        let_it_be(:node_kg2) { create(:zoekt_node, :knowledge_graph) }
        let_it_be(:replica) { create(:knowledge_graph_replica, zoekt_node: node_kg1) }

        it 'returns only nodes with knowledge graph service which are not used for the namespace' do
          expect(described_class.available_for_knowledge_graph_namespace(replica.knowledge_graph_enabled_namespace))
            .to contain_exactly(node_kg2)
        end
      end
    end

    describe '.with_reserved_bytes' do
      let_it_be(:node1) { create(:zoekt_node) }
      let_it_be(:node2) { create(:zoekt_node) }
      let_it_be(:node3) { create(:zoekt_node) }
      let_it_be(:replica1) { create(:knowledge_graph_replica, zoekt_node: node1, reserved_storage_bytes: 1000) }
      let_it_be(:index1) { create(:zoekt_index, node: node1, reserved_storage_bytes: 2000) }
      let_it_be(:index2) { create(:zoekt_index, node: node2, reserved_storage_bytes: 500) }

      subject(:with_reserved_bytes) { described_class.where(id: [node1, node2, node3]).with_reserved_bytes }

      it 'returns sum of reserved bytes or nil for each node' do
        expect(with_reserved_bytes.pluck(:reserved_storage_bytes_total)).to match_array([3000, 500, nil])
      end
    end

    describe '.negative_unclaimed_storage_bytes' do
      let_it_be(:node_with_negative_storage) { create(:zoekt_node) }
      let_it_be(:node_with_positive_storage) { create(:zoekt_node) }

      before do
        node_with_negative_storage.update!(total_bytes: 1000, used_bytes: 0, indexed_bytes: 0)
        node_with_positive_storage.update!(total_bytes: 2000, used_bytes: 0, indexed_bytes: 0)

        node_with_negative_storage.update!(usable_storage_bytes: 1000)
        node_with_positive_storage.update!(usable_storage_bytes: 2000)

        create(:zoekt_index, node: node_with_negative_storage, reserved_storage_bytes: 2000)
        create(:zoekt_index, node: node_with_positive_storage, reserved_storage_bytes: 500)
      end

      it 'includes only nodes with negative unclaimed storage' do
        expect(described_class.negative_unclaimed_storage_bytes.to_a).to include(node_with_negative_storage)
        expect(described_class.negative_unclaimed_storage_bytes.to_a).not_to include(node_with_positive_storage)
      end
    end

    describe '.with_positive_unclaimed_storage_bytes' do
      let_it_be(:node_with_positive_storage) { create(:zoekt_node, :enough_free_space) }
      let_it_be(:node_with_zero_storage) { create(:zoekt_node, total_bytes: 1000, used_bytes: 1000) }
      let_it_be(:node_with_negative_storage) { create(:zoekt_node, :enough_free_space) }

      # Scenario with positive unclaimed storage
      let_it_be(:index1) do
        create(:zoekt_index,
          node: node_with_positive_storage,
          reserved_storage_bytes: node_with_positive_storage.total_bytes / 3
        )
      end

      let_it_be(:replica1) do
        create(:knowledge_graph_replica,
          zoekt_node: node_with_positive_storage,
          reserved_storage_bytes: node_with_positive_storage.total_bytes / 3
        )
      end

      # Scenario with negative unclaimed storage
      let_it_be(:index2) do
        create(:zoekt_index,
          node: node_with_negative_storage,
          reserved_storage_bytes: (node_with_negative_storage.total_bytes / 2) + 10
        )
      end

      let_it_be(:replica2) do
        create(:knowledge_graph_replica,
          zoekt_node: node_with_negative_storage,
          reserved_storage_bytes: (node_with_negative_storage.total_bytes / 2) + 10
        )
      end

      it 'returns only nodes with non-negative unclaimed storage bytes' do
        positive_nodes = described_class.with_positive_unclaimed_storage_bytes

        expect(positive_nodes).to include(node_with_positive_storage)
        expect(positive_nodes).not_to include(node_with_zero_storage)
        expect(positive_nodes).not_to include(node_with_negative_storage)
      end

      it 'calculates unclaimed_storage_bytes correctly using SQL formula' do
        result = described_class.with_positive_unclaimed_storage_bytes

        expect(result).to match_array([node_with_positive_storage])
        expect(result[0]).to have_attribute('unclaimed_storage_bytes')
        expect(result[0]['unclaimed_storage_bytes']).to be > 0
        expect(result[0]['unclaimed_storage_bytes']).to eq(node_with_positive_storage.unclaimed_storage_bytes)
      end

      it 'groups results by node id to handle multiple indices' do
        # Create multiple indices for the same node
        create(:zoekt_index,
          node: node_with_positive_storage,
          reserved_storage_bytes: node_with_positive_storage.total_bytes / 4
        )

        results = described_class.with_positive_unclaimed_storage_bytes

        expect(results).to include(node_with_positive_storage)
      end

      context 'when no indices exist' do
        let_it_be(:node_without_indices) { create(:zoekt_node, :enough_free_space) }

        it 'includes nodes without indices if they have positive unclaimed storage' do
          results = described_class.with_positive_unclaimed_storage_bytes

          expect(results).to include(node_without_indices)
        end
      end
    end

    describe '.order_by_unclaimed_space_desc' do
      let_it_be(:node2) { create(:zoekt_node, :not_enough_free_space) }
      let_it_be(:node3) { create(:zoekt_node, :enough_free_space) }
      let_it_be(:node4) { create(:zoekt_node, :enough_free_space) }

      let_it_be(:index1) do
        create(:zoekt_index,
          node: node3,
          reserved_storage_bytes: 100_000
        )
      end

      let_it_be(:replica1) do
        create(:knowledge_graph_replica,
          zoekt_node: node3,
          reserved_storage_bytes: 100_000
        )
      end

      let_it_be(:replica2) do
        create(:knowledge_graph_replica,
          zoekt_node: node4,
          reserved_storage_bytes: 150_000
        )
      end

      it 'returns nodes with positive unclaimed storage_bytes in descending order' do
        expect(described_class.order_by_unclaimed_space_desc.to_a).to eq([node4, node3, node2])
      end
    end

    describe '.with_service' do
      let_it_be(:node1) { create(:zoekt_node, services: [described_class::SERVICES[:zoekt]]) }
      let_it_be(:node2) { create(:zoekt_node, services: [described_class::SERVICES[:knowledge_graph]]) }
      let_it_be(:node3) do
        create(:zoekt_node, services: [described_class::SERVICES[:zoekt], described_class::SERVICES[:knowledge_graph]])
      end

      it "returns nodes which contain the service in the list of services" do
        expect(described_class.with_service(:zoekt).to_a).to match_array([node, node1, node3])
        expect(described_class.with_service(:knowledge_graph).to_a).to match_array([node2, node3])
      end
    end
  end

  describe '.find_or_initialize_by_task_request', :freeze_time do
    let(:base_params) do
      {
        'uuid' => '3869fe21-36d1-4612-9676-0b783ef2dcd7',
        'node.name' => 'm1.local',
        'node.url' => 'http://localhost:6080',
        'disk.all' => 994662584320,
        'disk.free' => 461988872192,
        'disk.used' => 532673712128,
        'node.task_count' => 5,
        'node.concurrency' => 10
      }
    end

    subject(:tasked_node) { described_class.find_or_initialize_by_task_request(params) }

    context 'when node.search_url is unset' do
      let(:params) { base_params }

      it 'returns a new record with correct base_urls' do
        expect(tasked_node).not_to be_persisted
        expect(tasked_node.index_base_url).to eq(params['node.url'])
        expect(tasked_node.search_base_url).to eq(params['node.url'])
      end
    end

    context 'when node.search_url is set' do
      let(:params) { base_params.merge('node.search_url' => 'http://localhost:6090') }

      context 'when node does not exist for given UUID' do
        it 'returns a new record with correct attributes' do
          expect(tasked_node).not_to be_persisted
          expect(tasked_node.index_base_url).to eq(params['node.url'])
          expect(tasked_node.search_base_url).to eq(params['node.search_url'])
          expect(tasked_node.uuid).to eq(params['uuid'])
          expect(tasked_node.last_seen_at).to eq(Time.zone.now)
          expect(tasked_node.used_bytes).to eq(params['disk.used'])
          expect(tasked_node.total_bytes).to eq(params['disk.all'])
          expect(tasked_node.indexed_bytes).to eq 0
          expect(tasked_node.metadata['name']).to eq(params['node.name'])
          expect(tasked_node.metadata['task_count']).to eq(params['node.task_count'])
          expect(tasked_node.metadata['concurrency']).to eq(params['node.concurrency'])
          expect(tasked_node.metadata['version']).to be_nil
        end
      end

      context 'when node already exists for given UUID' do
        it 'returns existing node and updates correct attributes' do
          node.update!(uuid: params['uuid'])

          expect(tasked_node).to be_persisted
          expect(tasked_node.id).to eq(node.id)
          expect(tasked_node.index_base_url).to eq(params['node.url'])
          expect(tasked_node.search_base_url).to eq(params['node.search_url'])
          expect(tasked_node.uuid).to eq(params['uuid'])
          expect(tasked_node.last_seen_at).to eq(Time.zone.now)
          expect(tasked_node.used_bytes).to eq(params['disk.used'])
          expect(tasked_node.total_bytes).to eq(params['disk.all'])
          expect(tasked_node.indexed_bytes).to eq 0
          expect(tasked_node.metadata['name']).to eq(params['node.name'])
        end

        it 'allows creation of another node with the same URL' do
          node.update!(index_base_url: params['node.url'], search_base_url: params['node.url'])

          expect(tasked_node.save).to be(true)
        end
      end
    end

    context 'when disk.indexed is present' do
      let(:params) { base_params.merge('disk.indexed' => 2416879) }

      it 'sets indexed_bytes to the disk.indexed from params' do
        expect(tasked_node.indexed_bytes).to eq(params['disk.indexed'])
      end
    end

    context 'when node.version is present' do
      let(:params) { base_params.merge('node.version' => '1.2.3') }

      it 'sets version in metadata' do
        expect(tasked_node.metadata['version']).to eq('1.2.3')
      end
    end

    context 'when node.schema_version is present' do
      let(:params) { base_params.merge('node.schema_version' => 2525) }

      it 'sets schema_version' do
        expect(tasked_node.schema_version).to eq(2525)
      end
    end
  end

  describe '.marking_lost_enabled?', :zoekt_settings_enabled do
    before do
      allow(::Search::Zoekt::Settings).to receive(:lost_node_threshold).and_return(12.hours)
    end

    it 'returns true' do
      expect(described_class.marking_lost_enabled?).to be true
    end

    context 'when application setting zoekt_indexing_paused? is enabled' do
      before do
        stub_ee_application_setting(zoekt_indexing_paused: true)
      end

      it 'returns false' do
        expect(described_class.marking_lost_enabled?).to be false
      end
    end

    context 'when application setting zoekt_indexing_enabled? is disabled' do
      before do
        stub_ee_application_setting(zoekt_indexing_enabled: false)
      end

      it 'returns false' do
        expect(described_class.marking_lost_enabled?).to be false
      end
    end

    context 'when application setting zoekt_lost_node_threshold is disabled' do
      before do
        allow(::Search::Zoekt::Settings).to receive(:lost_node_threshold).and_return(nil)
      end

      it 'returns false' do
        expect(described_class.marking_lost_enabled?).to be false
      end
    end
  end

  describe '#metadata_json' do
    it 'returns a json with metadata' do
      node.update!(metadata: { name: 'test_name', task_count: 100, concurrency: 10, version: '2.0.0' })
      expected_json = {
        'zoekt.node_name' => 'test_name',
        'zoekt.node_id' => node.id,
        'zoekt.indexed_bytes' => 0,
        'zoekt.storage_percent_used' => node.storage_percent_used,
        'zoekt.used_bytes' => node.used_bytes,
        'zoekt.total_bytes' => node.total_bytes,
        'zoekt.task_count' => 100,
        'zoekt.concurrency' => 10,
        'zoekt.concurrency_limit' => 10,
        'zoekt.version' => '2.0.0'
      }

      expect(node.metadata_json).to eq(expected_json)
    end

    it 'does not return empty keys' do
      node.update!(metadata: { name: 'another_name' })
      expected_json = {
        'zoekt.node_name' => 'another_name',
        'zoekt.node_id' => node.id,
        'zoekt.indexed_bytes' => 0,
        'zoekt.storage_percent_used' => node.storage_percent_used,
        'zoekt.used_bytes' => node.used_bytes,
        'zoekt.total_bytes' => node.total_bytes,
        'zoekt.concurrency_limit' => node.concurrency_limit
      }

      expect(node.metadata_json).to eq(expected_json)
    end
  end

  describe '#concurrency_limit' do
    subject(:concurrency_limit) { node.concurrency_limit }

    context 'when node does not have task_count/concurrency set' do
      it 'returns the default limit' do
        expect(concurrency_limit).to eq(::Search::Zoekt::Node::DEFAULT_CONCURRENCY_LIMIT)
      end
    end

    context 'when node has task_count/concurrency set' do
      using RSpec::Parameterized::TableSyntax

      where(:concurrency, :concurrency_override, :multiplier, :result) do
        10  | nil | 1.0 | 10
        10  | nil | 1.5 | 15
        10  | nil | 2.0 | 20
        10  | 0   | 3.5 | 35
        3   | 0   | 2.5 | 8
        3   | 0   | 2.4 | 7
        1   | nil | 1.0 | 1
        1   | nil | 2.0 | 2
        10  | 20  | 1.5 | 20
        200 | nil | 1.0 | ::Search::Zoekt::Node::MAX_CONCURRENCY_LIMIT
        200 | nil | 1.5 | ::Search::Zoekt::Node::MAX_CONCURRENCY_LIMIT
        0   | nil | 1.5 | ::Search::Zoekt::Node::DEFAULT_CONCURRENCY_LIMIT
      end

      with_them do
        before do
          stub_ee_application_setting(zoekt_cpu_to_tasks_ratio: multiplier)
          node.metadata['concurrency'] = concurrency
          node.metadata['concurrency_override'] = concurrency_override
        end

        it 'returns correct value' do
          expect(concurrency_limit).to eq(result)
        end
      end
    end
  end

  describe '#storage_percent_used' do
    it 'is used storage / total reserved storage' do
      expect(node.storage_percent_used).to eq(node.used_bytes / node.total_bytes.to_f)
    end
  end

  describe '#watermark_exceeded_low?' do
    it 'returns true when over low limit' do
      node.used_bytes = 0
      expect(node).not_to be_watermark_exceeded_low

      node.used_bytes = node.total_bytes * ::Search::Zoekt::Node::WATERMARK_LIMIT_LOW
      expect(node).to be_watermark_exceeded_low
      expect(node).not_to be_watermark_exceeded_high
      expect(node).not_to be_watermark_exceeded_critical
    end
  end

  describe '#watermark_exceeded_high?' do
    it 'returns true when over high limit' do
      node.used_bytes = 0
      expect(node).not_to be_watermark_exceeded_high

      node.used_bytes = node.total_bytes * ::Search::Zoekt::Node::WATERMARK_LIMIT_HIGH
      expect(node).to be_watermark_exceeded_low
      expect(node).to be_watermark_exceeded_high
      expect(node).not_to be_watermark_exceeded_critical
    end
  end

  describe '#unclaimed_storage_bytes' do
    let(:test_node) { create(:zoekt_node) }

    it 'returns the difference between usable and reserved storage' do
      test_node.update!(total_bytes: 1000, used_bytes: 300, indexed_bytes: 200)
      test_node.save! # This triggers update_usable_storage_bytes

      allow(test_node).to receive(:reserved_storage_bytes).and_return(300)

      # usable_storage_bytes should be free_bytes + indexed_bytes = (1000 - 300) + 200 = 900
      # unclaimed_storage_bytes should be usable_storage_bytes - reserved_storage_bytes = 900 - 300 = 600
      expect(test_node.unclaimed_storage_bytes).to eq(600)
    end

    it 'returns usable_storage_bytes when there are no reserved bytes' do
      test_node.update!(total_bytes: 1000, used_bytes: 300, indexed_bytes: 200)
      test_node.save! # This triggers update_usable_storage_bytes

      allow(test_node).to receive(:reserved_storage_bytes).and_return(0)

      # usable_storage_bytes should be free_bytes + indexed_bytes = (1000 - 300) + 200 = 900
      # unclaimed_storage_bytes should be usable_storage_bytes - reserved_storage_bytes = 900 - 0 = 900
      expect(test_node.unclaimed_storage_bytes).to eq(900)
    end
  end

  describe '#watermark_exceeded_critical?' do
    it 'returns true when over critical limit' do
      node.used_bytes = 0
      expect(node).not_to be_watermark_exceeded_critical

      node.used_bytes = node.total_bytes * ::Search::Zoekt::Node::WATERMARK_LIMIT_CRITICAL
      expect(node).to be_watermark_exceeded_low
      expect(node).to be_watermark_exceeded_high
      expect(node).to be_watermark_exceeded_critical
    end
  end

  describe '#task_pull_frequency' do
    before do
      node.metadata['concurrency_override'] = 1
      node.save!
    end

    context 'when pending tasks is more than the concurrency_limit of a node' do
      before do
        create_list(:zoekt_task, 2, node: node)
      end

      it 'returns increased pull frequency' do
        expect(node.task_pull_frequency).to eq described_class::TASK_PULL_FREQUENCY_INCREASED
      end
    end

    context 'when pending tasks is equal to the concurrency_limit of a node' do
      before do
        create(:zoekt_task, node: node)
      end

      it 'returns increased pull frequency' do
        expect(node.task_pull_frequency).to eq described_class::TASK_PULL_FREQUENCY_INCREASED
      end
    end

    context 'when pending tasks is less than the concurrency_limit of a node' do
      it 'returns default pull frequency' do
        expect(node.task_pull_frequency).to eq described_class::TASK_PULL_FREQUENCY_DEFAULT
      end
    end
  end

  describe '#save_debounce', :freeze_time do
    context 'when record is persisted' do
      context 'when difference between updated_at and current time is more than DEBOUNCE_DELAY' do
        before do
          node.update_column :updated_at, (described_class::DEBOUNCE_DELAY + 1.second).ago
        end

        it 'returns true and calls save' do
          expect(node).to receive(:save).and_call_original
          expect(node.save_debounce).to be true
        end
      end

      context 'when difference between updated_at and current time is less than DEBOUNCE_DELAY' do
        before do
          node.update_column :updated_at, (described_class::DEBOUNCE_DELAY - 1.second).ago
        end

        it 'returns true and does not calls save' do
          expect(node).not_to receive(:save)
          expect(node.save_debounce).to be true
        end
      end
    end

    context 'when record is not persisted' do
      let(:new_node) { build(:zoekt_node) }

      it 'calls save' do
        expect(new_node).to receive(:save)
        new_node.save_debounce
      end
    end
  end

  describe '#usable_storage_bytes' do
    let_it_be_with_reload(:test_node) { create(:zoekt_node) }

    before do
      test_node.update!(total_bytes: 1000, used_bytes: 300, indexed_bytes: 200)
    end

    it 'must be a numerical value' do
      expect(test_node).to be_valid

      test_node.usable_storage_bytes = 'foo'
      expect(test_node).not_to be_valid
    end

    it 'must not be nil' do
      expect(test_node).to be_valid
      test_node.usable_storage_bytes = nil
      test_node.total_bytes = nil
      test_node.used_bytes = nil
      test_node.indexed_bytes = nil
      expect(test_node).not_to be_valid
    end

    it 'is set to free_bytes plus indexed_bytes on save' do
      test_node.save!
      expect(test_node.usable_storage_bytes).to eq(900) # (1000 - 300) + 200
    end

    context 'when usable_storage_bytes_locked_until is in the future' do
      it 'does not change whenever a node is saved' do
        node.usable_storage_bytes = 123
        node.usable_storage_bytes_locked_until = 1.hour.from_now
        node.save!
        expect(node.usable_storage_bytes).to eq(123)
      end
    end
  end

  describe '#usable_storage_bytes_locked_until' do
    context 'when in the future' do
      it 'does not change whenever the node is saved' do
        ttl = 1.hour.from_now
        node.usable_storage_bytes_locked_until = ttl
        node.save!
        expect(node.usable_storage_bytes_locked_until).to eq(ttl)
      end
    end

    context 'when in the past' do
      it 'changes whenever the node is saved' do
        node.usable_storage_bytes_locked_until = 1.hour.ago
        node.save!
        expect(node.usable_storage_bytes_locked_until).to be_nil
      end
    end
  end

  describe '#update_usable_storage_bytes' do
    it 'sets usable_storage_bytes to free_bytes plus indexed_bytes' do
      node.total_bytes = 1000
      node.used_bytes = 300
      node.indexed_bytes = 200

      node.save!

      expect(node.usable_storage_bytes).to eq(900) # (1000 - 300) + 200
    end

    context 'when usable_storage_bytes_locked_until is set' do
      it 'does not update when lock is in the future' do
        original_value = 500
        node.usable_storage_bytes = original_value
        node.usable_storage_bytes_locked_until = 1.hour.from_now

        node.save!

        expect(node.usable_storage_bytes).to eq(original_value)
      end

      it 'updates when lock is in the past' do
        node.usable_storage_bytes = 500
        node.usable_storage_bytes_locked_until = 1.hour.ago
        node.total_bytes = 1000
        node.used_bytes = 300
        node.indexed_bytes = 200

        node.save!

        expect(node.usable_storage_bytes).to eq(900)
        expect(node.usable_storage_bytes_locked_until).to be_nil
      end
    end
  end
end
