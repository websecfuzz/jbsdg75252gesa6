# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::BackfillAmazonGroupAuditEventDestinationsFixed,
  feature_category: :audit_events do
  let(:connection) { ApplicationRecord.connection }
  let(:organizations_table) { table(:organizations) }
  let(:namespaces_table) { table(:namespaces) }
  let(:legacy_table) { table(:audit_events_amazon_s3_configurations) }
  let(:streaming_table) { table(:audit_events_group_external_streaming_destinations) }

  let(:organization) { organizations_table.create!(name: 'organization', path: 'organization') }

  let!(:root_group) do
    namespaces_table.create!(
      organization_id: organization.id,
      name: 'gitlab-org',
      path: 'gitlab-org',
      type: 'Group'
    ).tap { |namespace| namespace.update!(traversal_ids: [namespace.id]) }
  end

  let!(:legacy_destination) do
    legacy_table.create!(
      name: "AWS S3 Bucket",
      namespace_id: root_group.id,
      access_key_xid: 'a' * 32,
      bucket_name: "example-bucket",
      aws_region: "us-west-2",
      encrypted_secret_access_key: 'a' * 32,
      encrypted_secret_access_key_iv: 'a' * 16,
      stream_destination_id: nil,
      created_at: 2.days.ago,
      updated_at: 1.day.ago
    )
  end

  let!(:legacy_destination2) do
    legacy_table.create!(
      name: "Second AWS S3 Bucket",
      namespace_id: root_group.id,
      access_key_xid: 'b' * 32,
      bucket_name: "second-bucket",
      aws_region: "eu-west-1",
      encrypted_secret_access_key: 'b' * 32,
      encrypted_secret_access_key_iv: 'b' * 16,
      stream_destination_id: nil
    )
  end

  let!(:streaming_destination) do
    streaming_table.create!(
      category: 2,
      group_id: root_group.id,
      name: "Already Migrated AWS Destination",
      config: { 'accessKeyXid' => 'c' * 32, 'bucketName' => 'migrated-bucket', 'awsRegion' => 'eu-central-1' },
      encrypted_secret_token: 'c' * 32,
      encrypted_secret_token_iv: 'c' * 16,
      legacy_destination_ref: nil,
      created_at: 3.days.ago,
      updated_at: 2.days.ago
    )
  end

  let!(:migrated_legacy_destination) do
    legacy_table.create!(
      name: "Already Migrated AWS S3 Bucket",
      namespace_id: root_group.id,
      access_key_xid: 'c' * 32,
      bucket_name: "migrated-bucket",
      aws_region: "eu-central-1",
      encrypted_secret_access_key: 'c' * 32,
      encrypted_secret_access_key_iv: 'c' * 16,
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
        start_id: legacy_destination.id,
        end_id: legacy_destination2.id,
        batch_table: :audit_events_amazon_s3_configurations,
        batch_column: :id,
        sub_batch_size: 2,
        pause_ms: 0,
        connection: connection
      )

      expect do
        migration.perform
      end.to change { streaming_table.count }.by(2)

      legacy_destination.reload
      legacy_destination2.reload

      expect(legacy_destination.stream_destination_id).not_to be_nil
      expect(legacy_destination2.stream_destination_id).not_to be_nil

      new_streaming_dest1 = streaming_table.find_by(legacy_destination_ref: legacy_destination.id)
      new_streaming_dest2 = streaming_table.find_by(legacy_destination_ref: legacy_destination2.id)

      expect(new_streaming_dest1.name).to eq(legacy_destination.name)
      expect(new_streaming_dest1.category).to eq(2)
      expect(new_streaming_dest1.group_id).to eq(root_group.id)

      config1 = new_streaming_dest1.config

      expect(config1['accessKeyXid']).to eq(legacy_destination.access_key_xid)
      expect(config1['bucketName']).to eq(legacy_destination.bucket_name)
      expect(config1['awsRegion']).to eq(legacy_destination.aws_region)

      expect(new_streaming_dest1.encrypted_secret_token).to eq(legacy_destination.encrypted_secret_access_key)
      expect(new_streaming_dest1.encrypted_secret_token_iv).to eq(legacy_destination.encrypted_secret_access_key_iv)

      expect(new_streaming_dest2.name).to eq(legacy_destination2.name)
      expect(new_streaming_dest2.group_id).to eq(root_group.id)

      config2 = new_streaming_dest2.config
      expect(config2['accessKeyXid']).to eq(legacy_destination2.access_key_xid)
      expect(config2['bucketName']).to eq(legacy_destination2.bucket_name)
      expect(config2['awsRegion']).to eq(legacy_destination2.aws_region)
    end

    it 'skips already migrated records' do
      migration = described_class.new(
        start_id: legacy_destination.id,
        end_id: migrated_legacy_destination.id,
        batch_table: :audit_events_amazon_s3_configurations,
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
        category: 2,
        group_id: root_group.id,
        name: "Reference for Already Migrated",
        config: { 'accessKeyXid' => 'd' * 32, 'bucketName' => 'reference-bucket', 'awsRegion' => 'us-east-1' },
        encrypted_secret_token: 'd' * 32,
        encrypted_secret_token_iv: 'd' * 16
      )

      in_range_but_migrated = legacy_table.create!(
        name: "In Range But Already Migrated",
        namespace_id: root_group.id,
        access_key_xid: 'd' * 32,
        bucket_name: "already-migrated-bucket",
        aws_region: "us-east-1",
        encrypted_secret_access_key: 'd' * 32,
        encrypted_secret_access_key_iv: 'd' * 16,
        stream_destination_id: reference_streaming.id,
        created_at: 1.day.ago,
        updated_at: 1.day.ago
      )

      test_migration = described_class.new(
        start_id: [legacy_destination.id, legacy_destination2.id, in_range_but_migrated.id].min,
        end_id: [legacy_destination.id, legacy_destination2.id, in_range_but_migrated.id].max,
        batch_table: :audit_events_amazon_s3_configurations,
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
