# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::BackfillReservedStorageBytes, feature_category: :global_search do
  subject(:migration) { described_class.new(**migration_args) }

  let!(:zoekt_nodes) { table(:zoekt_nodes) }
  let!(:namespaces) { table(:namespaces) }
  let!(:root_storage_statistics) { table(:namespace_root_storage_statistics) }
  let!(:zoekt_enabled_namespaces) { table(:zoekt_enabled_namespaces) }
  let!(:replicas) { table(:zoekt_replicas) }
  let!(:indices) { table(:zoekt_indices) }
  let!(:migration_args) do
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

  let!(:node) do
    zoekt_nodes.create!(uuid: SecureRandom.uuid, last_seen_at: Time.zone.now, used_bytes: 10, total_bytes: 100,
      search_base_url: "http://#{SecureRandom.hex(4)}.example.com",
      index_base_url: "http://#{SecureRandom.hex(4)}.example.com"
    )
  end

  let!(:organization) { table(:organizations).create!(name: 'organization', path: 'organization') }
  let!(:namespace) do
    namespaces.create!(name: 'my test group1', path: 'my-test-group1', organization_id: organization.id)
  end

  let!(:root_storage_statistic) { root_storage_statistics.create!(namespace_id: namespace.id, repository_size: 10) }
  let!(:zoekt_enabled_namespace) { zoekt_enabled_namespaces.create!(root_namespace_id: namespace.id) }
  let!(:replica) do
    replicas.create!(zoekt_enabled_namespace_id: zoekt_enabled_namespace.id, namespace_id: namespace.id)
  end

  let!(:index) do
    indices.create!(zoekt_enabled_namespace_id: zoekt_enabled_namespace.id, zoekt_node_id: node.id,
      namespace_id: namespace.id, zoekt_replica_id: replica.id, reserved_storage_bytes: nil
    )
  end

  let!(:namespace2) do
    namespaces.create!(name: 'my test group2', path: 'my-test-group2', organization_id: organization.id)
  end

  let!(:root_storage_statistic2) { root_storage_statistics.create!(namespace_id: namespace2.id, repository_size: 20) }
  let!(:zoekt_enabled_namespace2) { zoekt_enabled_namespaces.create!(root_namespace_id: namespace2.id) }
  let!(:replica2) do
    replicas.create!(zoekt_enabled_namespace_id: zoekt_enabled_namespace2.id, namespace_id: namespace2.id)
  end

  let!(:index2) do
    indices.create!(zoekt_enabled_namespace_id: zoekt_enabled_namespace2.id, zoekt_node_id: node.id,
      namespace_id: namespace2.id, zoekt_replica_id: replica2.id, reserved_storage_bytes: nil
    )
  end

  it 'ignores zoekt indices with missing enabled namespace' do
    index2.update!(zoekt_enabled_namespace_id: nil)
    migration.perform
    index_expected_reserved_storage_bytes = described_class::BUFFER_FACTOR * root_storage_statistic.repository_size
    index2_expected_reserved_storage_bytes = nil # nil because zoekt_enabled_namespace is missing
    expect(index.reload.reserved_storage_bytes).to eq index_expected_reserved_storage_bytes
    expect(index2.reload.reserved_storage_bytes).to eq index2_expected_reserved_storage_bytes
  end

  it 'backfills with default value of reserved_storage_bytes when root_storage_statistics is missing' do
    root_storage_statistic2.destroy!
    migration.perform
    index_expected_reserved_storage_bytes = described_class::BUFFER_FACTOR * root_storage_statistic.repository_size
    index2_expected_reserved_storage_bytes = described_class::DEFAULT_SIZE # Default since storage_statistic is missing
    expect(index.reload.reserved_storage_bytes).to eq index_expected_reserved_storage_bytes
    expect(index2.reload.reserved_storage_bytes).to eq index2_expected_reserved_storage_bytes # Default value
  end

  it 'correctly backfills the zoekt_replica_id for zoekt_indices' do
    migration.perform
    index_expected_reserved_storage_bytes = described_class::BUFFER_FACTOR * root_storage_statistic.repository_size
    index2_expected_reserved_storage_bytes = described_class::BUFFER_FACTOR * root_storage_statistic2.repository_size
    expect(index.reload.reserved_storage_bytes).to eq index_expected_reserved_storage_bytes
    expect(index2.reload.reserved_storage_bytes).to eq index2_expected_reserved_storage_bytes
  end

  it 'does not overwrites the reserved_storage_bytes if it is already present' do
    index_reserved_storage_bytes = 1
    index2_reserved_storage_bytes = 2
    index.update!(reserved_storage_bytes: index_reserved_storage_bytes)
    index2.update!(reserved_storage_bytes: index2_reserved_storage_bytes)
    migration.perform
    expect(index.reload.reserved_storage_bytes).to eq index_reserved_storage_bytes
    expect(index2.reload.reserved_storage_bytes).to eq index2_reserved_storage_bytes
  end
end
