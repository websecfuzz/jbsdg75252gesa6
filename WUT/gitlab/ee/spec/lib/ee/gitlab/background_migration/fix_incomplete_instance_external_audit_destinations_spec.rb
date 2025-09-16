# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::FixIncompleteInstanceExternalAuditDestinations, feature_category: :audit_events do
  let(:connection) { ApplicationRecord.connection }
  let(:organizations_table) { table(:organizations) }
  let(:namespaces_table) { table(:namespaces) }
  let(:legacy_table) { table(:audit_events_instance_external_audit_event_destinations) }
  let(:streaming_table) { table(:audit_events_instance_external_streaming_destinations) }
  let(:event_type_filters_table) { table(:audit_events_streaming_instance_event_type_filters) }
  let(:instance_event_type_filters_table) { table(:audit_events_instance_streaming_event_type_filters) }
  let(:namespace_filters_table) { table(:audit_events_streaming_http_instance_namespace_filters) }
  let(:instance_namespace_filters_table) { table(:audit_events_streaming_instance_namespace_filters) }
  let(:headers_table) { table(:instance_audit_events_streaming_headers) }

  let(:organization) { organizations_table.create!(name: 'test-org', path: 'test-org') }
  let!(:namespace) do
    namespaces_table.create!(
      organization_id: organization.id,
      name: 'test-group',
      path: 'test-group',
      type: 'Group'
    ).tap { |namespace| namespace.update!(traversal_ids: [namespace.id]) }
  end

  let!(:project) { create_project('test-project', namespace) }

  let!(:unmigrated_destination) do
    legacy_table.create!(
      name: "Unmigrated Destination",
      destination_url: "https://example.com/unmigrated",
      encrypted_verification_token: 'encrypted-token-1',
      encrypted_verification_token_iv: 'a' * 12,
      stream_destination_id: nil,
      created_at: 3.days.ago,
      updated_at: 2.days.ago
    )
  end

  let!(:complex_destination) do
    legacy_table.create!(
      name: "Complex Destination",
      destination_url: "https://example.com/complex",
      encrypted_verification_token: 'encrypted-token-2',
      encrypted_verification_token_iv: 'a' * 12,
      stream_destination_id: nil,
      created_at: 4.days.ago,
      updated_at: 3.days.ago
    )
  end

  let!(:partially_migrated_destination) do
    dest = legacy_table.create!(
      name: "Partially Migrated Destination",
      destination_url: "https://example.com/partial",
      encrypted_verification_token: 'encrypted-token-3',
      encrypted_verification_token_iv: 'a' * 12,
      created_at: 5.days.ago,
      updated_at: 4.days.ago
    )

    stream_dest = streaming_table.create!(
      name: dest.name,
      category: 0,
      config: {
        'url' => dest.destination_url,
        'headers' => {
          'X-Gitlab-Event-Streaming-Token' => {
            'value' => 'decrypted-token',
            'active' => true
          }
        }
      },
      encrypted_secret_token: 'encrypted-secret-1',
      encrypted_secret_token_iv: 'a' * 12,
      legacy_destination_ref: dest.id,
      created_at: dest.created_at,
      updated_at: dest.updated_at
    )

    dest.update!(stream_destination_id: stream_dest.id)
    dest
  end

  let!(:broken_encryption_destination) do
    legacy_table.create!(
      name: "Broken Encryption Destination",
      destination_url: "https://example.com/broken",
      encrypted_verification_token: 'invalid-encrypted-data',
      encrypted_verification_token_iv: 'invalid-iv-data',
      stream_destination_id: nil,
      created_at: 6.days.ago,
      updated_at: 6.days.ago
    )
  end

  let!(:complex_destination_headers) do
    [
      { key: 'X-Custom-Header-1', value: 'value-1', active: true },
      { key: 'X-Custom-Header-2', value: 'value-2', active: false }
    ].map do |header|
      headers_table.create!(
        instance_external_audit_event_destination_id: complex_destination.id,
        key: header[:key],
        value: header[:value],
        active: header[:active],
        created_at: 3.days.ago,
        updated_at: 3.days.ago
      )
    end
  end

  let!(:complex_destination_event_filters) do
    %w[user_created group_created project_created].map do |event_type|
      event_type_filters_table.create!(
        instance_external_audit_event_destination_id: complex_destination.id,
        audit_event_type: event_type,
        created_at: 3.days.ago,
        updated_at: 3.days.ago
      )
    end
  end

  let!(:complex_destination_namespace_filter) do
    namespace_filters_table.create!(
      audit_events_instance_external_audit_event_destination_id: complex_destination.id,
      namespace_id: namespace.id,
      created_at: 3.days.ago,
      updated_at: 3.days.ago
    )
  end

  let!(:missing_event_filter) do
    event_type_filters_table.create!(
      instance_external_audit_event_destination_id: partially_migrated_destination.id,
      audit_event_type: 'user_updated',
      created_at: 4.days.ago,
      updated_at: 4.days.ago
    )
  end

  let!(:existing_event_filter) do
    instance_event_type_filters_table.create!(
      external_streaming_destination_id: partially_migrated_destination.stream_destination_id,
      audit_event_type: 'group_created',
      created_at: 4.days.ago,
      updated_at: 4.days.ago
    )
  end

  let!(:missing_header) do
    headers_table.create!(
      instance_external_audit_event_destination_id: partially_migrated_destination.id,
      key: 'X-Missing-Header',
      value: 'missing-value',
      active: true,
      created_at: 4.days.ago,
      updated_at: 4.days.ago
    )
  end

  let!(:missing_namespace_filter) do
    namespace_filters_table.create!(
      audit_events_instance_external_audit_event_destination_id: partially_migrated_destination.id,
      namespace_id: namespace.id,
      created_at: 4.days.ago,
      updated_at: 4.days.ago
    )
  end

  let(:migration) do
    instance = described_class.new(
      start_id: [unmigrated_destination.id, complex_destination.id,
        partially_migrated_destination.id].min,
      end_id: [unmigrated_destination.id, complex_destination.id,
        partially_migrated_destination.id].max,
      batch_table: :audit_events_instance_external_audit_event_destinations,
      batch_column: :id,
      sub_batch_size: 5,
      pause_ms: 0,
      connection: connection
    )

    allow(instance).to receive(:decrypt_verification_token) do |dest|
      if dest.id == broken_encryption_destination.id
        nil
      else
        "decrypted-token-#{dest.id}"
      end
    end

    instance
  end

  def create_project(name, group)
    project_namespace = namespaces_table.create!(
      name: name,
      path: name,
      type: 'Project',
      organization_id: group.organization_id
    )

    table(:projects).create!(
      organization_id: group.organization_id,
      namespace_id: group.id,
      project_namespace_id: project_namespace.id,
      name: name,
      path: name
    )
  end

  it_behaves_like 'encrypted attribute', :verification_token, :db_key_base_32 do
    let(:record) { described_class::InstanceExternalAuditEventDestination.new }
  end

  it_behaves_like 'encrypted attribute', :secret_token, :db_key_base_32 do
    let(:record) { described_class::InstanceStreamingDestination.new }
  end

  describe '#perform' do
    before do
      allow(described_class::InstanceStreamingDestination).to receive(:new).and_wrap_original do |original, *args|
        instance = original.call(*args)
        allow(instance).to receive(:db_key_base_32).and_return('a' * 32)
        allow(instance).to receive(:encrypt_secret_token) do
          instance.encrypted_secret_token = "encrypted-#{instance.instance_variable_get(:@secret_token)}"
          instance.encrypted_secret_token_iv = "iv-#{SecureRandom.hex(6)}"
        end
        instance
      end

      allow(Encryptor).to receive(:encrypt).and_return("encrypted-token")

      allow(::Gitlab::CryptoHelper).to receive(:aes256_gcm_decrypt).and_return("decrypted-token")
    end

    it 'creates streaming destinations for unmigrated records' do
      expect { migration.perform }.to change { streaming_table.count }.by(2)

      unmigrated_destination.reload
      complex_destination.reload
      broken_encryption_destination.reload

      expect(unmigrated_destination.stream_destination_id).to be_present
      expect(complex_destination.stream_destination_id).to be_present
      expect(broken_encryption_destination.stream_destination_id).to be_nil
    end

    it 'skips destinations with broken encryption' do
      broken_migration = described_class.new(
        start_id: broken_encryption_destination.id,
        end_id: broken_encryption_destination.id,
        batch_table: :audit_events_instance_external_audit_event_destinations,
        batch_column: :id,
        sub_batch_size: 1,
        pause_ms: 0,
        connection: connection
      )

      allow(broken_migration).to receive(:decrypt_verification_token).and_return(nil)

      expect { broken_migration.perform }.not_to change { streaming_table.count }

      broken_encryption_destination.reload
      expect(broken_encryption_destination.stream_destination_id).to be_nil
    end

    it 'properly migrates config from legacy destination' do
      migration.perform

      unmigrated_destination.reload
      stream_dest = streaming_table.find(unmigrated_destination.stream_destination_id)

      expect(stream_dest.name).to eq(unmigrated_destination.name)
      expect(stream_dest.category).to eq(0)
      expect(stream_dest.config['url']).to eq(unmigrated_destination.destination_url)
      expect(stream_dest.config['headers']).to include('X-Gitlab-Event-Streaming-Token')
    end

    it 'migrates custom headers correctly' do
      migration.perform

      complex_destination.reload
      stream_dest = streaming_table.find(complex_destination.stream_destination_id)

      headers = stream_dest.config['headers']
      expect(headers.keys).to include('X-Custom-Header-1', 'X-Custom-Header-2')
      expect(headers['X-Custom-Header-1']['value']).to eq('value-1')
      expect(headers['X-Custom-Header-1']['active']).to be true
      expect(headers['X-Custom-Header-2']['value']).to eq('value-2')
      expect(headers['X-Custom-Header-2']['active']).to be false
    end

    it 'migrates event type filters correctly' do
      expect { migration.perform }.to change { instance_event_type_filters_table.count }.by(4)

      complex_destination.reload
      filters = instance_event_type_filters_table.where(
        external_streaming_destination_id: complex_destination.stream_destination_id
      )

      expect(filters.count).to eq(3)
      expect(filters.pluck(:audit_event_type)).to match_array(%w[user_created group_created project_created])
    end

    it 'migrates namespace filters correctly' do
      expect { migration.perform }.to change { instance_namespace_filters_table.count }.by(2)

      complex_destination.reload
      partially_migrated_destination.reload

      complex_filters = instance_namespace_filters_table.where(
        external_streaming_destination_id: complex_destination.stream_destination_id
      )
      expect(complex_filters.count).to eq(1)
      expect(complex_filters.first.namespace_id).to eq(namespace.id)

      partial_filters = instance_namespace_filters_table.where(
        external_streaming_destination_id: partially_migrated_destination.stream_destination_id
      )
      expect(partial_filters.count).to eq(1)
      expect(partial_filters.first.namespace_id).to eq(namespace.id)
    end

    it 'syncs missing data for partially migrated destinations' do
      migration.perform

      partially_migrated_destination.reload
      stream_dest = streaming_table.find(partially_migrated_destination.stream_destination_id)

      headers = stream_dest.config['headers']
      expect(headers).to include('X-Missing-Header')
      expect(headers['X-Missing-Header']['value']).to eq('missing-value')
      expect(headers['X-Missing-Header']['active']).to be true

      filters = instance_event_type_filters_table.where(
        external_streaming_destination_id: partially_migrated_destination.stream_destination_id
      )
      expect(filters.pluck(:audit_event_type)).to include('user_updated', 'group_created')
    end

    it 'correctly handles validation cases when decrypting verification tokens' do
      test_migration = described_class.new(
        start_id: 1,
        end_id: 10,
        batch_table: :audit_events_instance_external_audit_event_destinations,
        batch_column: :id,
        sub_batch_size: 5,
        pause_ms: 0,
        connection: connection
      )

      valid_dest = legacy_table.create!(
        name: "Valid Encryption Destination",
        destination_url: "https://example.com/valid",
        encrypted_verification_token: 'valid-encrypted-token',
        encrypted_verification_token_iv: 'b' * 12,
        stream_destination_id: nil
      )

      empty_dest = legacy_table.create!(
        name: "Empty Encryption Destination",
        destination_url: "https://example.com/empty",
        encrypted_verification_token: '',
        encrypted_verification_token_iv: 'c' * 12,
        stream_destination_id: nil
      )

      invalid_dest = legacy_table.create!(
        name: "Invalid Data Destination",
        destination_url: "https://example.com/invalid",
        encrypted_verification_token: 'invalid-encrypted-token',
        encrypted_verification_token_iv: 'd' * 12,
        stream_destination_id: nil
      )

      expect(::Gitlab::CryptoHelper).to receive(:aes256_gcm_decrypt)
        .with(valid_dest.encrypted_verification_token, nonce: valid_dest.encrypted_verification_token_iv)
        .and_return("decrypted-test-token")

      expect(::Gitlab::CryptoHelper).to receive(:aes256_gcm_decrypt)
        .with(invalid_dest.encrypted_verification_token, nonce: invalid_dest.encrypted_verification_token_iv)
        .and_raise(OpenSSL::Cipher::CipherError)

      expect(test_migration.send(:decrypt_verification_token, valid_dest)).to eq("decrypted-test-token")

      expect(test_migration.send(:decrypt_verification_token, empty_dest)).to be_nil

      expect(test_migration.send(:decrypt_verification_token, invalid_dest)).to be_nil
    end

    it 'skips migration for destinations with empty token data' do
      empty_token_dest = legacy_table.create!(
        name: "Empty Token Destination",
        destination_url: "https://example.com/empty-token",
        encrypted_verification_token: '',
        encrypted_verification_token_iv: 'e' * 12,
        stream_destination_id: nil
      )

      migration_for_empty = described_class.new(
        start_id: empty_token_dest.id,
        end_id: empty_token_dest.id,
        batch_table: :audit_events_instance_external_audit_event_destinations,
        batch_column: :id,
        sub_batch_size: 1,
        pause_ms: 0,
        connection: connection
      )

      allow(migration_for_empty).to receive(:decrypt_verification_token).and_call_original
      allow(::Gitlab::CryptoHelper).to receive(:aes256_gcm_decrypt).and_raise(OpenSSL::Cipher::CipherError)

      expect { migration_for_empty.perform }.not_to change { streaming_table.count }

      empty_token_dest.reload
      expect(empty_token_dest.stream_destination_id).to be_nil
    end

    context 'with error handling' do
      it 'handles validation failures gracefully' do
        duplicate_name = legacy_table.create!(
          name: "Duplicate #{partially_migrated_destination.name}",
          destination_url: "https://example.com/duplicate",
          encrypted_verification_token: 'encrypted-token-dup',
          encrypted_verification_token_iv: 'iv-dup',
          stream_destination_id: nil
        )

        validation_migration = described_class.new(
          start_id: duplicate_name.id,
          end_id: duplicate_name.id,
          batch_table: :audit_events_instance_external_audit_event_destinations,
          batch_column: :id,
          sub_batch_size: 1,
          pause_ms: 0,
          connection: connection
        )

        allow(validation_migration).to receive(:migrate_new_record).and_return(nil)

        expect { validation_migration.perform }.not_to change { streaming_table.count }

        duplicate_name.reload
        expect(duplicate_name.stream_destination_id).to be_nil
      end
    end

    context 'with sub-batching' do # rubocop:disable RSpec/MultipleMemoizedHelpers -- need to build out data
      let!(:additional_destinations) do
        (1..6).map do |i|
          legacy_table.create!(
            name: "Batch Destination #{i}",
            destination_url: "https://example.com/batch-#{i}",
            encrypted_verification_token: "encrypted-token-batch-#{i}",
            encrypted_verification_token_iv: "iv-batch-#{i}",
            stream_destination_id: nil
          )
        end
      end

      it 'processes records in sub-batches' do
        sub_batch_migration = described_class.new(
          start_id: additional_destinations.map(&:id).min,
          end_id: additional_destinations.map(&:id).max,
          batch_table: :audit_events_instance_external_audit_event_destinations,
          batch_column: :id,
          sub_batch_size: 2,
          pause_ms: 0,
          connection: connection
        )

        allow(sub_batch_migration).to receive(:decrypt_verification_token) do |dest|
          "decrypted-token-#{dest.id}"
        end

        allow(sub_batch_migration).to receive(:process_batch) do |batch|
          batch.each do |dest|
            token = "decrypted-token-#{dest.id}"

            destination = described_class::InstanceStreamingDestination.new(
              name: dest.name,
              category: :http,
              config: {
                'url' => dest.destination_url,
                'headers' => {
                  'X-Gitlab-Event-Streaming-Token' => {
                    'value' => token,
                    'active' => true
                  }
                }
              },
              legacy_destination_ref: dest.id,
              created_at: dest.created_at,
              updated_at: dest.updated_at
            )

            destination.secret_token = token
            destination.save!

            dest.update!(stream_destination_id: destination.id)
          end
        end

        expect { sub_batch_migration.perform }.to change { streaming_table.count }.by(6)

        additional_destinations.each do |dest|
          dest.reload
          expect(dest.stream_destination_id).to be_present
        end
      end
    end
  end
end
