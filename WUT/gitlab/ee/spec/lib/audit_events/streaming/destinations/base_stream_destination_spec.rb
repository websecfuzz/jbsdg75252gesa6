# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::Streaming::Destinations::BaseStreamDestination, feature_category: :audit_events do
  let_it_be(:audit_event) { create(:audit_event, :group_event) }
  let(:event_type) { 'event_type' }
  let(:destination) { create(:audit_events_instance_external_streaming_destination, :http) }
  let(:base_destination) { described_class.new(event_type, audit_event, destination) }

  describe '#stream' do
    it 'raises NotImplementedError' do
      expect { base_destination.stream }.to raise_error(NotImplementedError)
    end
  end

  describe '#request_body' do
    subject(:request_body) { base_destination.send(:request_body) }

    it 'returns json with required fields', :aggregate_failures do
      body = Gitlab::Json.parse(request_body)

      expect(body['event_type']).to eq(event_type)
      expect(body['id']).to eq(audit_event.id)
    end
  end
end
