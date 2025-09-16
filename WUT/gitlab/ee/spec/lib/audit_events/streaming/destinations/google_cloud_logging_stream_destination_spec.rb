# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::Streaming::Destinations::GoogleCloudLoggingStreamDestination, feature_category: :audit_events do
  let_it_be(:audit_event) { create(:audit_event, :group_event) }
  let(:event_type) { 'event_type' }
  let(:destination) { create(:audit_events_instance_external_streaming_destination, :gcp) }
  let(:google_cloud_destination) { described_class.new(event_type, audit_event, destination) }

  describe '#stream' do
    let(:gcp_logger) { instance_double(AuditEvents::GoogleCloud::LoggingService::Logger) }

    before do
      allow(AuditEvents::GoogleCloud::LoggingService::Logger).to receive(:new).and_return(gcp_logger)
    end

    it 'logs the audit event to Google Cloud Logging' do
      expect(gcp_logger).to receive(:log).with(
        destination.config["clientEmail"],
        destination.secret_token,
        google_cloud_destination.send(:json_payload)
      )

      google_cloud_destination.stream
    end

    context 'when an error occurs' do
      before do
        allow(gcp_logger).to receive(:log).and_raise(StandardError.new('GCP error'))
      end

      it 'logs the exception' do
        expect(Gitlab::ErrorTracking).to receive(:log_exception).with(kind_of(StandardError))

        google_cloud_destination.stream
      end
    end
  end

  describe '#json_payload' do
    subject(:json_payload) { google_cloud_destination.send(:json_payload) }

    it 'returns a JSON string with the correct structure' do
      payload = Gitlab::Json.parse(json_payload)

      expect(payload).to be_a(Hash)
      expect(payload['entries']).to be_an(Array)
      expect(payload['entries'].first).to include(
        'logName',
        'resource',
        'severity',
        'jsonPayload'
      )
    end
  end

  describe '#log_entry' do
    subject(:log_entry) { google_cloud_destination.send(:log_entry) }

    it 'returns a hash with the correct structure' do
      expect(log_entry).to include(
        'logName' => a_kind_of(String),
        'resource' => { 'type' => 'global' },
        'severity' => 'INFO',
        'jsonPayload' => a_kind_of(Hash)
      )
    end
  end

  describe '#full_log_path' do
    subject(:full_log_path) { google_cloud_destination.send(:full_log_path) }

    it 'returns the correct log path' do
      path = "projects/#{destination.config['googleProjectIdName']}/logs/#{destination.config['logIdName']}"
      expect(full_log_path).to eq(path)
    end
  end
end
