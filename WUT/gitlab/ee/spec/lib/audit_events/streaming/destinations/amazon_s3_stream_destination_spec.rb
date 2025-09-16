# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::Streaming::Destinations::AmazonS3StreamDestination, feature_category: :audit_events do
  let_it_be(:audit_event) { create(:audit_event, :group_event) }
  let(:event_type) { 'event_type' }
  let(:destination) { create(:audit_events_instance_external_streaming_destination, :aws) }
  let(:s3_destination) { described_class.new(event_type, audit_event, destination) }

  describe '#stream' do
    let(:aws_s3_client) { instance_double(Aws::S3Client) }
    let(:bucket_name) { 'test-bucket' }
    let(:filename) { 'group/2023/09/event_type_1_1694441509820.json' }

    before do
      allow(s3_destination).to receive_messages(
        aws_s3_client: aws_s3_client,
        bucket_name: bucket_name,
        filename: filename
      )
    end

    it 'uploads the audit event to S3' do
      expect(aws_s3_client).to receive(:upload_object).with(
        filename,
        bucket_name,
        kind_of(String),
        'application/json'
      )

      s3_destination.stream
    end

    context 'when an error occurs' do
      before do
        allow(aws_s3_client).to receive(:upload_object).and_raise(StandardError.new('Unexpected error'))
      end

      it 'tracks the exception' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(kind_of(StandardError))

        s3_destination.stream
      end
    end

    context 'when S3 specific error occurs' do
      before do
        allow(aws_s3_client).to receive(:upload_object).and_raise(Aws::S3::Errors::ServiceError.new(nil,
          "S3 Service Error"))
      end

      it 'logs the exception' do
        expect(Gitlab::ErrorTracking).to receive(:log_exception).with(kind_of(Aws::S3::Errors::ServiceError))

        s3_destination.stream
      end
    end
  end

  describe '#filename' do
    subject(:filename) { s3_destination.send(:filename, payload) }

    let(:payload) { s3_destination.send(:request_body) }

    it 'returns the correct filename format' do
      expect(filename).to match(%r{group/\d{4}/\d{2}/event_type_\d+_\d+\.json})
    end

    context 'when entity_type is Gitlab::Audit::InstanceScope' do
      let(:audit_event) { create(:audit_event, :instance_event) }

      it 'uses "instance" in the filename' do
        expect(filename).to start_with('instance/')
      end
    end

    context 'when entity_type is Namespaces::UserNamespace' do
      let(:audit_event) { create(:audit_event, entity_type: "Namespaces::UserNamespace") }

      it 'uses "user" in the filename' do
        expect(filename).to start_with('user/')
      end
    end

    context 'when entity_type is neither Namespaces::UserNamespace or Gitlab::Audit::InstanceScope' do
      let(:audit_event) { create(:audit_event, entity_type: "Other::Entity::Type") }

      it 'uses "other_entity_type" in the filename' do
        expect(filename).to start_with('other_entity_type/')
      end
    end
  end

  describe '#aws_s3_client' do
    it 'initializes an AWS S3 client with correct credentials' do
      expect(Aws::S3Client).to receive(:new).with(
        destination.config["accessKeyXid"],
        destination.secret_token,
        destination.config["awsRegion"]
      )

      s3_destination.send(:aws_s3_client)
    end

    it 'memoizes the client' do
      client = instance_double(Aws::S3Client)
      allow(Aws::S3Client).to receive(:new).and_return(client)

      expect(s3_destination.send(:aws_s3_client)).to eq(client)
      expect(Aws::S3Client).to have_received(:new).once

      expect(s3_destination.send(:aws_s3_client)).to eq(client)
      expect(Aws::S3Client).to have_received(:new).once
    end
  end

  describe '#bucket_name' do
    it 'returns the bucket name from the destination configuration' do
      expect(s3_destination.send(:bucket_name)).to eq(destination.config["bucketName"])
    end
  end
end
