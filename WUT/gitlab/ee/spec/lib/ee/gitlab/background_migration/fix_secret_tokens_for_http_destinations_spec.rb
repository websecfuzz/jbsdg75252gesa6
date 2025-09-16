# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::FixSecretTokensForHttpDestinations,
  feature_category: :audit_events do
  let(:connection) { ::ApplicationRecord.connection }
  let(:organizations_table) { table(:organizations) }
  let(:namespaces_table) { table(:namespaces) }
  let(:legacy_table) { table(:audit_events_external_audit_event_destinations) }
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

  let!(:test_group) do
    namespaces_table.create!(
      organization_id: organization.id,
      name: 'test-group',
      path: 'test-group',
      type: 'Group'
    ).tap { |namespace| namespace.update!(traversal_ids: [namespace.id]) }
  end

  let!(:working_http_destination) do
    dest = described_class::GroupStreamingDestination.create!(
      name: "Working HTTP Destination",
      category: :http,
      config: {
        'url' => 'https://example.com/working',
        'headers' => {
          'Some-Token' => {
            'value' => 'working-token',
            'active' => true
          }
        }
      },
      group_id: root_group.id,
      secret_token: 'working-secret-token'
    )

    streaming_table.find(dest.id)
  end

  let!(:corrupted_http_destination_with_legacy) do
    legacy_dest = legacy_table.create!(
      name: "Legacy HTTP Destination",
      namespace_id: root_group.id,
      destination_url: "https://example.com/legacy",
      verification_token: "original-legacy-token",
      created_at: 3.days.ago,
      updated_at: 2.days.ago
    )

    real_destination = described_class::GroupStreamingDestination.create!(
      name: "Corrupted with Legacy",
      category: :http,
      config: {
        'url' => 'https://example.com/corrupted-legacy',
        'headers' => {
          'X-Test-Header' => {
            'value' => 'test-value',
            'active' => true
          }
        }
      },
      group_id: root_group.id,
      legacy_destination_ref: legacy_dest.id,
      secret_token: 'temp-token-12345'
    )

    real_destination.update_columns(
      encrypted_secret_token: Base64.encode64('corrupted-data-that-cannot-decrypt'),
      encrypted_secret_token_iv: Base64.encode64('bad-iv-too-short')
    )

    streaming_table.find(real_destination.id)
  end

  let!(:corrupted_http_destination_without_legacy) do
    real_destination = described_class::GroupStreamingDestination.create!(
      name: "Corrupted without Legacy",
      category: :http,
      config: {
        'url' => 'https://example.com/corrupted-no-legacy',
        'headers' => {
          'X-Test-Header' => {
            'value' => 'test-value',
            'active' => true
          }
        }
      },
      group_id: test_group.id,
      secret_token: 'temp-token-12345'
    )

    real_destination.update_columns(
      encrypted_secret_token: Base64.encode64('corrupted-data-cannot-decrypt'),
      encrypted_secret_token_iv: Base64.encode64('bad-iv-short')
    )

    streaming_table.find(real_destination.id)
  end

  let(:migration) do
    described_class.new(
      start_id: [working_http_destination.id, corrupted_http_destination_with_legacy.id,
        corrupted_http_destination_without_legacy.id].min,
      end_id: [working_http_destination.id, corrupted_http_destination_with_legacy.id,
        corrupted_http_destination_without_legacy.id].max,
      batch_table: :audit_events_group_external_streaming_destinations,
      batch_column: :id,
      sub_batch_size: 5,
      pause_ms: 0,
      connection: connection
    )
  end

  describe '#perform' do
    before do
      encryption_key = 'a' * 32

      described_class::GroupStreamingDestination.class_eval do
        define_method(:db_key_base_32) do
          encryption_key
        end
      end

      described_class::LegacyGroupHttpDestination.class_eval do
        define_method(:db_key_base_32) do
          encryption_key
        end
      end
    end

    it 'only processes HTTP destinations that are corrupted' do
      expect { migration.perform }.not_to raise_error

      fixed_dest1 = described_class::GroupStreamingDestination.find(corrupted_http_destination_with_legacy.id)
      fixed_dest2 = described_class::GroupStreamingDestination.find(corrupted_http_destination_without_legacy.id)

      expect { fixed_dest1.secret_token }.not_to raise_error
      expect { fixed_dest2.secret_token }.not_to raise_error
    end

    it 'skips destinations that are not corrupted' do
      expect do
        working_http_destination.reload
        described_class::GroupStreamingDestination.find(working_http_destination.id).secret_token
      end.not_to raise_error

      migration.perform

      expect do
        working_http_destination.reload
        described_class::GroupStreamingDestination.find(working_http_destination.id).secret_token
      end.not_to raise_error
    end

    it 'fixes corrupted destination with legacy token' do
      destination = described_class::GroupStreamingDestination.find(corrupted_http_destination_with_legacy.id)
      expect { destination.secret_token }.to raise_error(ArgumentError, /iv must be 12 bytes/)

      migration.perform

      destination.reload
      expect { destination.secret_token }.not_to raise_error
      expect(destination.secret_token).to eq("original-legacy-token")
    end

    it 'fixes corrupted destination without legacy token by generating new one' do
      destination = described_class::GroupStreamingDestination.find(corrupted_http_destination_without_legacy.id)
      expect { destination.secret_token }.to raise_error(ArgumentError, /iv must be 12 bytes/)

      migration.perform

      destination.reload
      expect { destination.secret_token }.not_to raise_error
      expect(destination.secret_token).to be_present
      expect(destination.secret_token.length).to eq(24)
    end

    it 'handles encryption/decryption errors gracefully' do
      allow_any_instance_of(described_class::GroupStreamingDestination) do |instance|
        allow(instance).to receive(:save!).and_raise(StandardError, "Save failed")
      end

      expect { migration.perform }.not_to raise_error
    end

    context 'when legacy destination is not found' do
      before do
        legacy_table.where(id: corrupted_http_destination_with_legacy.legacy_destination_ref).delete_all
      end

      it 'generates a new token when legacy destination is missing' do
        migration.perform

        destination = described_class::GroupStreamingDestination.find(corrupted_http_destination_with_legacy.id)
        expect { destination.secret_token }.not_to raise_error
        expect(destination.secret_token).to be_present
        expect(destination.secret_token.length).to eq(24)
      end
    end
  end

  describe 'helper methods' do
    let(:migration_instance) do
      described_class.new(
        start_id: 1, end_id: 100,
        batch_table: :audit_events_group_external_streaming_destinations,
        batch_column: :id, sub_batch_size: 5, pause_ms: 0, connection: connection
      )
    end

    before do
      encryption_key = 'a' * 32

      described_class::GroupStreamingDestination.class_eval do
        define_method(:db_key_base_32) do
          encryption_key
        end
      end
    end

    describe '#http_destination_corrupted?' do
      it 'returns false for working destination' do
        migration_model = described_class::GroupStreamingDestination

        working_dest = migration_model.new(
          name: "Test Working",
          category: :http,
          config: { 'url' => 'https://example.com' },
          group_id: root_group.id
        )
        working_dest.secret_token = 'test-token'
        working_dest.save!

        found_dest = migration_model.find(working_dest.id)
        expect(migration_instance.send(:http_destination_corrupted?, found_dest)).to be false

        working_dest.destroy!
      end

      it 'returns true for destination with cipher error' do
        destination = described_class::GroupStreamingDestination.find(corrupted_http_destination_with_legacy.id)
        expect(migration_instance.send(:http_destination_corrupted?, destination)).to be true
      end
    end

    describe '#get_original_http_token' do
      it 'returns legacy token when legacy destination exists' do
        destination = described_class::GroupStreamingDestination.find(corrupted_http_destination_with_legacy.id)
        token = migration_instance.send(:get_original_http_token, destination)
        expect(token).to eq("original-legacy-token")
      end

      it 'returns nil when no legacy destination reference' do
        destination = described_class::GroupStreamingDestination.find(corrupted_http_destination_without_legacy.id)
        token = migration_instance.send(:get_original_http_token, destination)
        expect(token).to be_nil
      end

      it 'returns nil when legacy destination does not exist' do
        destination = described_class::GroupStreamingDestination.find(corrupted_http_destination_with_legacy.id)
        legacy_table.where(id: destination.legacy_destination_ref).delete_all

        token = migration_instance.send(:get_original_http_token, destination)
        expect(token).to be_nil
      end
    end
  end
end
