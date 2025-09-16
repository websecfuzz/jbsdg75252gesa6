# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/MultipleMemoizedHelpers -- We need extra helpers to define tables
RSpec.describe Gitlab::BackgroundMigration::FixIncompleteExternalAuditDestinations,
  feature_category: :audit_events do
  let(:connection) { ::ApplicationRecord.connection }
  let(:organizations_table) { table(:organizations) }
  let(:namespaces_table) { table(:namespaces) }
  let(:legacy_table) { table(:audit_events_external_audit_event_destinations) }
  let(:streaming_table) { table(:audit_events_group_external_streaming_destinations) }
  let(:event_type_filters_table) { table(:audit_events_streaming_event_type_filters) }
  let(:group_event_type_filters_table) { table(:audit_events_group_streaming_event_type_filters) }
  let(:namespace_filters_table) { table(:audit_events_streaming_http_group_namespace_filters) }
  let(:group_namespace_filters_table) { table(:audit_events_streaming_group_namespace_filters) }
  let(:headers_table) { table(:audit_events_streaming_headers) }
  let(:organization) { organizations_table.create!(name: 'organization', path: 'organization') }

  let!(:root_group) do
    namespaces_table.create!(
      organization_id: organization.id,
      name: 'gitlab-org',
      path: 'gitlab-org',
      type: 'Group'
    ).tap { |namespace| namespace.update!(traversal_ids: [namespace.id]) }
  end

  let!(:subgroup1) do
    namespaces_table.create!(
      organization_id: organization.id,
      name: 'gitlab-subgroup1',
      path: 'gitlab-subgroup1',
      type: 'Group',
      parent_id: root_group.id
    ).tap { |namespace| namespace.update!(traversal_ids: [root_group.id, namespace.id]) }
  end

  let!(:subgroup2) do
    namespaces_table.create!(
      organization_id: organization.id,
      name: 'gitlab-subgroup2',
      path: 'gitlab-subgroup2',
      type: 'Group',
      parent_id: root_group.id
    ).tap { |namespace| namespace.update!(traversal_ids: [root_group.id, namespace.id]) }
  end

  let!(:simple_destination) do
    legacy_table.create!(
      name: "Simple HTTP Destination",
      namespace_id: root_group.id,
      destination_url: "https://example.com/simple",
      verification_token: "simple-token-12345",
      stream_destination_id: nil,
      created_at: 3.days.ago,
      updated_at: 2.days.ago
    )
  end

  let!(:complex_destination) do
    legacy_table.create!(
      name: "Complex Destination",
      namespace_id: root_group.id,
      destination_url: "https://example.com/complex",
      verification_token: "complex-token-67890",
      stream_destination_id: nil,
      created_at: 2.days.ago,
      updated_at: 1.day.ago
    )
  end

  let!(:migrated_destination) do
    destination = legacy_table.create!(
      name: "Already Migrated Destination",
      namespace_id: root_group.id,
      destination_url: "https://example.com/migrated",
      verification_token: "migrated-token-54321",
      created_at: 4.days.ago,
      updated_at: 3.days.ago
    )

    streaming_dest = streaming_table.create!(
      name: destination.name,
      category: 0,
      config: {
        'url' => destination.destination_url,
        'headers' => {
          'X-Gitlab-Event-Streaming-Token' => {
            'value' => destination.verification_token,
            'active' => true
          }
        }
      },
      encrypted_secret_token: 'test-token',
      encrypted_secret_token_iv: 'test-iv-vector',
      legacy_destination_ref: destination.id,
      group_id: destination.namespace_id,
      created_at: destination.created_at,
      updated_at: destination.updated_at
    )

    destination.update!(stream_destination_id: streaming_dest.id)
    destination
  end

  let!(:invalid_destination) do
    legacy_table.create!(
      name: "Invalid Destination",
      namespace_id: root_group.id,
      destination_url: "https://example.com/invalid",
      verification_token: nil,
      stream_destination_id: nil,
      created_at: 5.days.ago,
      updated_at: 5.days.ago
    )
  end

  let!(:event_type_filters_with_group_id) do
    %w[user_created group_created].map do |event_type|
      event_type_filters_table.create!(
        external_audit_event_destination_id: complex_destination.id,
        audit_event_type: event_type,
        group_id: root_group.id,
        created_at: 1.day.ago,
        updated_at: 1.day.ago
      )
    end
  end

  let!(:event_type_filter_without_group_id) do
    event_type_filters_table.create!(
      external_audit_event_destination_id: complex_destination.id,
      audit_event_type: 'project_created',
      group_id: nil,
      created_at: 1.day.ago,
      updated_at: 1.day.ago
    )
  end

  let!(:migrated_event_type_filter) do
    group_event_type_filters_table.create!(
      external_streaming_destination_id: migrated_destination.stream_destination_id,
      audit_event_type: 'user_created',
      namespace_id: root_group.id,
      created_at: 3.days.ago,
      updated_at: 3.days.ago
    )
  end

  let!(:missing_event_type_filter) do
    event_type_filters_table.create!(
      external_audit_event_destination_id: migrated_destination.id,
      audit_event_type: 'group_created',
      group_id: root_group.id,
      created_at: 3.days.ago,
      updated_at: 3.days.ago
    )
  end

  let!(:namespace_filter) do
    namespace_filters_table.create!(
      external_audit_event_destination_id: complex_destination.id,
      namespace_id: subgroup1.id,
      created_at: 1.day.ago,
      updated_at: 1.day.ago
    )
  end

  let!(:headers_with_group_id) do
    [
      { key: 'X-Custom-Header-1', value: 'custom-value-1', active: true }
    ].map do |header_data|
      headers_table.create!(
        external_audit_event_destination_id: complex_destination.id,
        key: header_data[:key],
        value: header_data[:value],
        active: header_data[:active],
        group_id: root_group.id,
        created_at: 1.day.ago,
        updated_at: 1.day.ago
      )
    end
  end

  let!(:header_without_group_id) do
    headers_table.create!(
      external_audit_event_destination_id: complex_destination.id,
      key: 'X-Custom-Header-2',
      value: 'custom-value-2',
      active: false,
      group_id: nil,
      created_at: 1.day.ago,
      updated_at: 1.day.ago
    )
  end

  let!(:missing_header_for_migrated) do
    headers_table.create!(
      external_audit_event_destination_id: migrated_destination.id,
      key: 'X-Migrated-Header',
      value: 'migrated-value',
      active: true,
      group_id: root_group.id,
      created_at: 3.days.ago,
      updated_at: 3.days.ago
    )
  end

  let(:migration) do
    described_class.new(
      start_id: [simple_destination.id, complex_destination.id, migrated_destination.id, invalid_destination.id].min,
      end_id: [simple_destination.id, complex_destination.id, migrated_destination.id, invalid_destination.id].max,
      batch_table: :audit_events_external_audit_event_destinations,
      batch_column: :id,
      sub_batch_size: 5,
      pause_ms: 0,
      connection: connection
    )
  end

  it_behaves_like 'encrypted attribute', :secret_token, :db_key_base_32 do
    let(:record) { described_class::GroupStreamingDestination.new }
  end

  describe '#perform' do
    before do
      encryption_key = 'a' * 32

      described_class::GroupStreamingDestination.class_eval do
        define_method(:db_key_base_32) do
          encryption_key
        end
      end

      described_class::ExternalAuditEventDestination.class_eval do
        define_method(:db_key_base_32) do
          encryption_key
        end
      end
    end

    it 'creates streaming destinations for unmigrated records and updates migrated ones' do
      expect { migration.perform }.to change { streaming_table.count }.by(2)

      simple_destination.reload
      complex_destination.reload
      migrated_destination.reload
      invalid_destination.reload

      expect(simple_destination.stream_destination_id).not_to be_nil
      expect(complex_destination.stream_destination_id).not_to be_nil
      expect(migrated_destination.stream_destination_id).not_to be_nil
      expect(invalid_destination.stream_destination_id).to be_nil

      new_dest = streaming_table.find_by(id: simple_destination.stream_destination_id)
      expect(new_dest.encrypted_secret_token).to be_present
      expect(new_dest.encrypted_secret_token_iv).to be_present
    end

    it 'properly migrates a simple destination without filters or headers' do
      migration.perform

      simple_destination.reload
      new_streaming_dest = streaming_table.find_by(legacy_destination_ref: simple_destination.id)

      expect(new_streaming_dest.name).to eq(simple_destination.name)
      expect(new_streaming_dest.category).to eq(0)
      expect(new_streaming_dest.group_id).to eq(root_group.id)

      config = new_streaming_dest.config
      expect(config['url']).to eq(simple_destination.destination_url)
      expect(config['headers']).to be_a(Hash)

      expect(group_event_type_filters_table.where(external_streaming_destination_id: new_streaming_dest.id).count)
        .to eq(0)
      expect(group_namespace_filters_table.where(external_streaming_destination_id: new_streaming_dest.id).count)
        .to eq(0)

      expect(new_streaming_dest.encrypted_secret_token).to be_present
      expect(new_streaming_dest.encrypted_secret_token_iv).to be_present
    end

    it 'properly migrates a complex destination with all related data including those without group_id' do
      migration.perform

      complex_destination.reload
      new_streaming_dest = streaming_table.find_by(legacy_destination_ref: complex_destination.id)

      expect(new_streaming_dest.name).to eq(complex_destination.name)
      expect(new_streaming_dest.category).to eq(0)
      expect(new_streaming_dest.group_id).to eq(root_group.id)

      config = new_streaming_dest.config
      expect(config['url']).to eq(complex_destination.destination_url)
      expect(config['headers']['X-Custom-Header-1']['value']).to eq('custom-value-1')
      expect(config['headers']['X-Custom-Header-1']['active']).to be(true)
      expect(config['headers']['X-Custom-Header-2']['value']).to eq('custom-value-2')
      expect(config['headers']['X-Custom-Header-2']['active']).to be(false)

      migrated_filters = group_event_type_filters_table.where(external_streaming_destination_id: new_streaming_dest.id)
      expect(migrated_filters.count).to eq(3)
      expect(migrated_filters.pluck(:audit_event_type)).to match_array(%w[user_created group_created project_created])

      migrated_namespace_filter = group_namespace_filters_table
        .where(external_streaming_destination_id: new_streaming_dest.id)
      expect(migrated_namespace_filter.count).to eq(1)
      expect(migrated_namespace_filter.first.namespace_id).to eq(subgroup1.id)
    end

    it 'adds missing headers and event type filters to already migrated destinations' do
      migration.perform

      migrated_destination.reload
      streaming_dest = streaming_table.find_by(id: migrated_destination.stream_destination_id)

      expect(streaming_dest.config['headers']['X-Migrated-Header']['value']).to eq('migrated-value')
      expect(streaming_dest.config['headers']['X-Migrated-Header']['active']).to be(true)

      migrated_filters = group_event_type_filters_table.where(external_streaming_destination_id: streaming_dest.id)
      expect(migrated_filters.count).to eq(2)
      expect(migrated_filters.pluck(:audit_event_type)).to match_array(%w[user_created group_created])
    end

    it 'skips destinations without verification token' do
      migration.perform

      invalid_destination.reload
      expect(invalid_destination.stream_destination_id).to be_nil
      expect(streaming_table.find_by(legacy_destination_ref: invalid_destination.id)).to be_nil
    end

    context 'with migrated record missing token header' do
      before do
        migrated_streaming_dest = streaming_table.find(migrated_destination.stream_destination_id)
        config = migrated_streaming_dest.config
        config['headers'].delete('X-Gitlab-Event-Streaming-Token')
        migrated_streaming_dest.update!(config: config)
      end

      it 'adds the token header when missing' do
        migration.perform

        migrated_streaming_dest = streaming_table.find(migrated_destination.stream_destination_id)
        expect(migrated_streaming_dest.config['headers']).to have_key('X-Gitlab-Event-Streaming-Token')
        expect(migrated_streaming_dest.config['headers']['X-Gitlab-Event-Streaming-Token']['value'])
          .to eq('migrated-token-54321')
        expect(migrated_streaming_dest.config['headers']['X-Gitlab-Event-Streaming-Token']['active']).to be true
      end
    end

    context 'with namespace filters for migrated destination' do
      let!(:migrated_namespace_filter) do
        namespace_filters_table.create!(
          external_audit_event_destination_id: migrated_destination.id,
          namespace_id: subgroup2.id,
          created_at: 3.days.ago,
          updated_at: 3.days.ago
        )
      end

      it 'migrates missing namespace filters for already migrated destinations' do
        expect { migration.perform }.to change {
          group_namespace_filters_table.count
        }.by(2)

        namespace_filter = group_namespace_filters_table
          .find_by(external_streaming_destination_id: migrated_destination.stream_destination_id)
        expect(namespace_filter).not_to be_nil
        expect(namespace_filter.namespace_id).to eq(subgroup2.id)
      end
    end

    context 'with multiple batch processing' do
      let!(:additional_destinations) do
        (1..10).map do |i|
          legacy_table.create!(
            name: "Batch Destination #{i}",
            namespace_id: root_group.id,
            destination_url: "https://example.com/batch-#{i}",
            verification_token: "batch-token-#{i}",
            stream_destination_id: nil,
            created_at: 5.days.ago,
            updated_at: 4.days.ago
          )
        end
      end

      let(:migration) do
        described_class.new(
          start_id: ([simple_destination.id, complex_destination.id,
            migrated_destination.id, invalid_destination.id] + additional_destinations.map(&:id)).min,
          end_id: ([simple_destination.id, complex_destination.id,
            migrated_destination.id, invalid_destination.id] + additional_destinations.map(&:id)).max,
          batch_table: :audit_events_external_audit_event_destinations,
          batch_column: :id,
          sub_batch_size: 5,
          pause_ms: 0,
          connection: connection
        )
      end

      it 'processes all valid records across multiple batches' do
        expect { migration.perform }.to change { streaming_table.count }.by(12)

        (additional_destinations + [simple_destination, complex_destination]).each do |destination|
          expect(destination.reload.stream_destination_id).not_to be_nil
        end

        expect(invalid_destination.reload.stream_destination_id).to be_nil
      end
    end

    context 'with migration failures' do
      before do
        group_event_type_filters_table.create!(
          external_streaming_destination_id: migrated_destination.stream_destination_id,
          audit_event_type: 'group_created',
          namespace_id: root_group.id,
          created_at: 3.days.ago,
          updated_at: 3.days.ago
        )
      end

      it 'continues processing other records when one fails' do
        expect { migration.perform }.to change { streaming_table.count }.by(2)

        simple_destination.reload
        complex_destination.reload

        expect(simple_destination.stream_destination_id).not_to be_nil
        expect(complex_destination.stream_destination_id).not_to be_nil
      end
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
