# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::FixStringConfigHashesInstanceStreamingDestinations, feature_category: :audit_events do
  let(:namespaces) { table(:namespaces) }
  let(:namespaces_id) { namespaces.create!(name: 'test', path: 'test').id }
  let(:destinations) { table(:audit_events_instance_external_streaming_destinations) }

  subject(:migration) do
    described_class.new(
      batch_table: :audit_events_instance_external_streaming_destinations,
      batch_column: :id,
      sub_batch_size: 2,
      pause_ms: 0,
      connection: ApplicationRecord.connection,
      start_id: 1,
      end_id: 10000
    )
  end

  describe '#perform' do
    before do
      destinations.create!(
        name: 'test1',
        config: '{"url":"https://example.com"}',
        encrypted_secret_token: 'token',
        encrypted_secret_token_iv: 'iv',
        category: 1,
        created_at: Time.current,
        updated_at: Time.current
      )

      destinations.create!(
        name: 'test2',
        config: "{'url':'https://example.com'}",
        encrypted_secret_token: 'token',
        encrypted_secret_token_iv: 'iv',
        category: 1,
        created_at: Time.current,
        updated_at: Time.current
      )

      destinations.create!(
        name: 'test3',
        config: { url: 'https://example.com' },
        encrypted_secret_token: 'token',
        encrypted_secret_token_iv: 'iv',
        category: 1,
        created_at: Time.current,
        updated_at: Time.current
      )
    end

    it 'converts string configs to jsonb objects' do
      expect do
        migration.perform
      end.to change {
        destinations.where("jsonb_typeof(config) = 'string'").count
      }.from(2).to(0)

      # All records should now have object configs
      expect(destinations.where("jsonb_typeof(config) = 'object'").count).to eq(3)

      # Check the values were properly parsed
      destination1 = destinations.find_by(name: 'test1')
      destination2 = destinations.find_by(name: 'test2')

      expect(destination1.config).to eq({ 'url' => 'https://example.com' })
      expect(destination2.config).to eq({ 'url' => 'https://example.com' })
    end
  end
end
