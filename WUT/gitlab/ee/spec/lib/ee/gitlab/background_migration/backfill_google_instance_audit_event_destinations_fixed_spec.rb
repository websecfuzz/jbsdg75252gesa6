# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::BackfillGoogleInstanceAuditEventDestinationsFixed,
  feature_category: :audit_events do
  let(:connection) { ApplicationRecord.connection }
  let(:legacy_table) { table(:audit_events_instance_google_cloud_logging_configurations) }
  let(:streaming_table) { table(:audit_events_instance_external_streaming_destinations) }

  let!(:legacy_destination1) do
    legacy_table.create!(
      name: "Test GCP Instance Destination 1",
      google_project_id_name: "test-project-1",
      log_id_name: "test-log-1",
      client_email: "test1@example.com",
      encrypted_private_key: 'a' * 32,
      encrypted_private_key_iv: 'a' * 16,
      stream_destination_id: nil,
      created_at: 2.days.ago,
      updated_at: 1.day.ago
    )
  end

  let!(:legacy_destination2) do
    legacy_table.create!(
      name: "Test GCP Instance Destination 2",
      google_project_id_name: "test-project-2",
      log_id_name: "test-log-2",
      client_email: "test2@example.com",
      encrypted_private_key: 'b' * 32,
      encrypted_private_key_iv: 'b' * 16,
      stream_destination_id: nil,
      created_at: 3.days.ago,
      updated_at: 2.days.ago
    )
  end

  let!(:streaming_destination) do
    streaming_table.create!(
      category: 1,
      name: "Already Migrated GCP Destination",
      config: { 'googleProjectIdName' => 'migrated-project', 'logIdName' => 'migrated-log',
                'clientEmail' => 'migrated@example.com' },
      encrypted_secret_token: 'c' * 32,
      encrypted_secret_token_iv: 'c' * 16,
      legacy_destination_ref: nil,
      created_at: 3.days.ago,
      updated_at: 2.days.ago
    )
  end

  let!(:migrated_legacy_destination) do
    legacy_table.create!(
      name: "Already Migrated GCP Instance Destination",
      google_project_id_name: "migrated-project",
      log_id_name: "migrated-log",
      client_email: "migrated@example.com",
      encrypted_private_key: 'c' * 32,
      encrypted_private_key_iv: 'c' * 16,
      stream_destination_id: streaming_destination.id,
      created_at: 3.days.ago,
      updated_at: 2.days.ago
    )
  end

  before do
    streaming_destination.update!(legacy_destination_ref: migrated_legacy_destination.id)
  end

  describe '#perform' do
    it 'creates streaming destinations for unmigrated records and updates them with correct encryption keys' do
      migration = described_class.new(
        start_id: legacy_destination1.id,
        end_id: legacy_destination2.id,
        batch_table: :audit_events_instance_google_cloud_logging_configurations,
        batch_column: :id,
        sub_batch_size: 2,
        pause_ms: 0,
        connection: connection
      )

      expect do
        migration.perform
      end.to change { streaming_table.count }.by(2)

      legacy_destination1.reload
      legacy_destination2.reload

      expect(legacy_destination1.stream_destination_id).not_to be_nil
      expect(legacy_destination2.stream_destination_id).not_to be_nil

      new_streaming_dest1 = streaming_table.find_by(legacy_destination_ref: legacy_destination1.id)
      new_streaming_dest2 = streaming_table.find_by(legacy_destination_ref: legacy_destination2.id)

      expect(new_streaming_dest1.name).to eq(legacy_destination1.name)
      expect(new_streaming_dest1.category).to eq(1)

      config1 = new_streaming_dest1.config

      expect(config1['googleProjectIdName']).to eq(legacy_destination1.google_project_id_name)
      expect(config1['logIdName']).to eq(legacy_destination1.log_id_name)
      expect(config1['clientEmail']).to eq(legacy_destination1.client_email)

      expect(new_streaming_dest1.encrypted_secret_token).to eq(legacy_destination1.encrypted_private_key)
      expect(new_streaming_dest1.encrypted_secret_token_iv).to eq(legacy_destination1.encrypted_private_key_iv)

      expect(new_streaming_dest2.name).to eq(legacy_destination2.name)
    end

    it 'skips already migrated records' do
      migration = described_class.new(
        start_id: legacy_destination1.id,
        end_id: migrated_legacy_destination.id,
        batch_table: :audit_events_instance_google_cloud_logging_configurations,
        batch_column: :id,
        sub_batch_size: 10,
        pause_ms: 0,
        connection: connection
      )

      expect do
        migration.perform
      end.to change { streaming_table.count }.by(2)

      expect(migrated_legacy_destination.reload.stream_destination_id).to eq(streaming_destination.id)
    end

    it 'only processes records with nil stream_destination_id' do
      reference_streaming = streaming_table.create!(
        category: 1,
        name: "Reference for Already Migrated",
        config: { 'googleProjectIdName' => 'reference-project', 'logIdName' => 'reference-log',
                  'clientEmail' => 'reference@example.com' },
        encrypted_secret_token: 'd' * 32,
        encrypted_secret_token_iv: 'd' * 16
      )

      in_range_but_migrated = legacy_table.create!(
        name: "In Range But Already Migrated",
        google_project_id_name: "reference-project",
        log_id_name: "reference-log",
        client_email: "reference@example.com",
        encrypted_private_key: 'd' * 32,
        encrypted_private_key_iv: 'd' * 16,
        stream_destination_id: reference_streaming.id,
        created_at: 1.day.ago,
        updated_at: 1.day.ago
      )

      test_migration = described_class.new(
        start_id: [legacy_destination1.id, legacy_destination2.id, in_range_but_migrated.id].min,
        end_id: [legacy_destination1.id, legacy_destination2.id, in_range_but_migrated.id].max,
        batch_table: :audit_events_instance_google_cloud_logging_configurations,
        batch_column: :id,
        sub_batch_size: 3,
        pause_ms: 0,
        connection: connection
      )

      expect do
        test_migration.perform
      end.to change { streaming_table.count }.by(2)

      in_range_but_migrated.reload
      expect(in_range_but_migrated.stream_destination_id).to eq(reference_streaming.id)
    end
  end
end
