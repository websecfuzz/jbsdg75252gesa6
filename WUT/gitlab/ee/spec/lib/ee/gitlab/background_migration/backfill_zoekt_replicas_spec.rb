# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::BackfillZoektReplicas,
  schema: 20240629011500,
  feature_category: :global_search do
  subject(:migration) { described_class.new(**migration_args) }

  let(:namespaces) { table(:namespaces) }
  let(:zoekt_enabled_namespaces) { table(:zoekt_enabled_namespaces) }
  let(:zoekt_nodes) { table(:zoekt_nodes) }
  let(:indices) { table(:zoekt_indices) }
  let(:replicas) { table(:zoekt_replicas) }
  let(:zkt_node_1) { create_zoekt_node }
  let(:zkt_node_2) { create_zoekt_node }
  let(:migration_args) do
    {
      start_id: indices.minimum(:id),
      end_id: indices.maximum(:id),
      batch_table: :zoekt_indices,
      batch_column: :id,
      sub_batch_size: 1,
      pause_ms: 0,
      connection: ApplicationRecord.connection
    }
  end

  it 'correctly backfills the zoekt_replica_id for zoekt_indices' do
    np_1 = namespaces.create!(name: 'my test group1', path: 'my-test-group1')
    np_2 = namespaces.create!(name: 'my test group2', path: 'my-test-group2')
    zkt_np_1 = zoekt_enabled_namespaces.create!(root_namespace_id: np_1.id)
    zkt_np_2 = zoekt_enabled_namespaces.create!(root_namespace_id: np_2.id)

    replica_for_zkt_np_2 = create_zoekt_replica_for_enabled_namespace(zkt_np_2)

    zkt_np_1_idx_1 = create_zoekt_index_for_enabled_namespace(zkt_np_1, node: zkt_node_1)
    zkt_np_2_idx_1 = create_zoekt_index_for_enabled_namespace(zkt_np_2, node: zkt_node_2,
      zoekt_replica_id: replica_for_zkt_np_2.id)
    zkt_np_2_idx_2 = create_zoekt_index_for_enabled_namespace(zkt_np_2, node: zkt_node_1)
    zkt_np_1_idx_2 = create_zoekt_index_for_enabled_namespace(zkt_np_1, node: zkt_node_2)

    migration.perform

    replica_for_zkt_np_1 = replicas.last

    expect(zkt_np_1_idx_1.reload.zoekt_replica_id).to eq(replica_for_zkt_np_1.id)
    expect(zkt_np_1_idx_2.reload.zoekt_replica_id).to eq(replica_for_zkt_np_1.id)
    expect(zkt_np_2_idx_1.reload.zoekt_replica_id).to eq(replica_for_zkt_np_2.id)
    expect(zkt_np_2_idx_2.reload.zoekt_replica_id).to eq(replica_for_zkt_np_2.id)
  end

  it 'ignores zoekt indices with missing enabled namespace' do
    np_1 = namespaces.create!(name: 'my test group1', path: 'my-test-group1')
    zkt_np_1 = zoekt_enabled_namespaces.create!(root_namespace_id: np_1.id)
    zkt_np_1_idx_1 = create_zoekt_index_for_enabled_namespace(zkt_np_1, node: zkt_node_1)
    zkt_np_1_idx_1.update!(zoekt_enabled_namespace_id: nil)

    expect(zkt_np_1_idx_1.zoekt_replica_id).to be_nil
    migration.perform
    expect(zkt_np_1_idx_1.zoekt_replica_id).to be_nil
  end

  def create_zoekt_index_for_enabled_namespace(zkt_enabled_namespace, node:, zoekt_replica_id: nil)
    indices.create!(
      zoekt_enabled_namespace_id: zkt_enabled_namespace.id,
      namespace_id: zkt_enabled_namespace.root_namespace_id,
      zoekt_replica_id: zoekt_replica_id,
      zoekt_node_id: node.id
    )
  end

  def create_zoekt_replica_for_enabled_namespace(zkt_enabled_namespace)
    replicas.create!(
      zoekt_enabled_namespace_id: zkt_enabled_namespace.id,
      namespace_id: zkt_enabled_namespace.root_namespace_id
    )
  end

  def create_zoekt_node
    zoekt_nodes.create!(
      index_base_url: "http://#{SecureRandom.hex(4)}.example.com",
      search_base_url: "http://#{SecureRandom.hex(4)}.example.com",
      uuid: SecureRandom.uuid,
      last_seen_at: Time.zone.now,
      used_bytes: 10,
      total_bytes: 100
    )
  end
end
