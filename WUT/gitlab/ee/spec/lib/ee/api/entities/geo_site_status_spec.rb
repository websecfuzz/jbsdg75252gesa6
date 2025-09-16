# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::API::Entities::GeoSiteStatus, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  let!(:geo_node_status) { build(:geo_node_status) }
  let(:entity) { described_class.new(geo_node_status, request: double) }
  let(:error) { 'Could not connect to Geo database' }

  subject { entity.as_json }

  before do
    stub_primary_node
  end

  describe '#healthy' do
    context 'when site is healthy' do
      it 'returns true' do
        expect(subject[:healthy]).to eq true
      end
    end

    context 'when site is unhealthy' do
      before do
        geo_node_status.status_message = error
      end

      subject { entity.as_json }

      it 'returns false' do
        expect(subject[:healthy]).to eq false
      end
    end
  end

  describe '#health' do
    context 'when site is healthy' do
      it 'exposes the health message' do
        expect(subject[:health]).to eq GeoNodeStatus::HEALTHY_STATUS
      end
    end

    context 'when site is unhealthy' do
      before do
        geo_node_status.status_message = error
      end

      subject { entity.as_json }

      it 'exposes the error message' do
        expect(subject[:health]).to eq error
      end
    end
  end

  describe '#job_artifacts_synced_in_percentage' do
    it 'formats as percentage' do
      geo_node_status.assign_attributes(
        job_artifacts_registry_count: 256,
        job_artifacts_failed_count: 12,
        job_artifacts_synced_count: 123
      )

      expect(subject[:job_artifacts_synced_in_percentage]).to eq '48.05%'
    end
  end

  describe '#container_repositories_synced_in_percentage' do
    it 'formats as percentage' do
      geo_node_status.assign_attributes(
        container_repositories_registry_count: 256,
        container_repositories_failed_count: 12,
        container_repositories_synced_count: 123
      )

      expect(subject[:container_repositories_synced_in_percentage]).to eq '48.05%'
    end
  end

  describe '#replication_slots_used_in_percentage' do
    it 'formats as percentage' do
      geo_node_status.assign_attributes(
        replication_slots_count: 4,
        replication_slots_used_count: 2
      )

      expect(subject[:replication_slots_used_in_percentage]).to eq '50.00%'
    end
  end

  describe '#namespaces' do
    it 'returns empty array when full sync is active' do
      expect(subject[:namespaces]).to be_empty
    end

    it 'returns array of namespace ids and paths for selective sync' do
      namespace = create(:namespace)
      geo_node_status.geo_node.namespaces << namespace

      expect(subject[:namespaces]).not_to be_empty
      expect(subject[:namespaces]).to be_an(Array)
      expect(subject[:namespaces].first[:id]).to eq(namespace.id)
      expect(subject[:namespaces].first[:path]).to eq(namespace.path)
    end
  end

  describe '#storage_shards' do
    it 'returns the config' do
      shards = StorageShard.all

      expect(subject[:storage_shards].count).to eq(shards.count)
      expect(subject[:storage_shards].first[:name]).to eq(shards.first.name)
    end
  end

  context 'when secondary Geo site' do
    before do
      stub_secondary_node
    end

    it { is_expected.to have_key(:storage_shards) }
    it { is_expected.to have_key(:storage_shards_match) }
  end
end
