# frozen_string_literal: true
require 'spec_helper'

RSpec.describe EE::GeoHelper, feature_category: :geo_replication do
  describe '.current_node_human_status' do
    where(:primary, :secondary, :result) do
      [
        [true, false, s_('Geo|primary')],
        [false, true, s_('Geo|secondary')],
        [false, false, s_('Geo|misconfigured')]
      ]
    end

    with_them do
      it 'returns correct results' do
        allow(::Gitlab::Geo).to receive(:primary?).and_return(primary)
        allow(::Gitlab::Geo).to receive(:secondary?).and_return(secondary)

        expect(described_class.current_node_human_status).to eq result
      end
    end
  end

  describe '#replicable_types' do
    subject(:replicable_types) { helper.replicable_types }

    it 'includes all replicator_class_data' do
      expected_replicable_types = Gitlab::Geo::REPLICATOR_CLASSES.map { |c| replicable_class_data(c) }

      expect(replicable_types).to include(*expected_replicable_types)
    end
  end

  describe '#replicable_class_data' do
    let(:replicator) { Gitlab::Geo.replication_enabled_replicator_classes[0] }

    subject(:replicable_class_data) { helper.replicable_class_data(replicator) }

    it 'returns the correct data map' do
      expect(replicable_class_data).to eq({
        data_type: replicator.data_type,
        data_type_title: replicator.data_type_title,
        data_type_sort_order: replicator.data_type_sort_order,
        title: replicator.replicable_title,
        title_plural: replicator.replicable_title_plural,
        name: replicator.replicable_name,
        name_plural: replicator.replicable_name_plural,
        graphql_field_name: replicator.graphql_field_name,
        graphql_registry_class: replicator.registry_class,
        graphql_mutation_registry_class: replicator.graphql_mutation_registry_class,
        replication_enabled: replicator.replication_enabled?,
        verification_enabled: replicator.verification_enabled?,
        graphql_registry_id_type: Types::GlobalIDType[replicator.registry_class].to_s
      })
    end
  end

  describe '#geo_filter_nav_options' do
    let(:replicable_controller) { 'admin/geo/replicables' }
    let(:replicable_name) { 'projects' }
    let(:expected_nav_options) do
      [
        { value: "", text: "All projects", href: "/admin/geo/replication/projects" },
        { value: "pending", text: "In progress", href: "/admin/geo/replication/projects?sync_status=pending" },
        { value: "failed", text: "Failed", href: "/admin/geo/replication/projects?sync_status=failed" },
        { value: "synced", text: "Synced", href: "/admin/geo/replication/projects?sync_status=synced" }
      ]
    end

    subject(:geo_filter_nav_options) { helper.geo_filter_nav_options(replicable_controller, replicable_name) }

    it 'returns correct urls' do
      expect(geo_filter_nav_options).to eq(expected_nav_options)
    end
  end

  describe '#format_file_size_for_checksum' do
    context 'when file size is of even length' do
      it 'returns same file size string' do
        expect(helper.format_file_size_for_checksum("12")).to eq("12")
      end
    end

    context 'when file size is of odd length' do
      it 'returns even length file size string with a padded leading zero' do
        expect(helper.format_file_size_for_checksum("123")).to eq("0123")
      end
    end

    context 'when file size is 0' do
      it 'returns even length file size string with a padded leading zero' do
        expect(helper.format_file_size_for_checksum("0")).to eq("00")
      end
    end
  end
end
