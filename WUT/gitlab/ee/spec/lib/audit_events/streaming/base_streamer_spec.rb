# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::Streaming::BaseStreamer, feature_category: :audit_events do
  let_it_be(:audit_event) { create(:audit_event, :group_event) }
  let(:event_type) { 'event_type ' }
  let(:streamer) { described_class.new(event_type, audit_event) }

  describe '#initialize' do
    it 'sets audit operation and event' do
      expect(streamer.event_type).to eq(event_type)
      expect(streamer.audit_event).to eq(audit_event)
    end
  end

  describe '#streamable?' do
    it 'raises NotImplementedError' do
      expect { streamer.streamable? }.to raise_error(NotImplementedError)
    end
  end

  describe '#destinations' do
    it 'raises NotImplementedError' do
      expect { streamer.send(:destinations) }.to raise_error(NotImplementedError)
    end
  end

  describe '#execute' do
    let(:destination) { build(:audit_events_group_external_streaming_destination, :http) }
    let(:http_streamer) { instance_double(AuditEvents::Streaming::Destinations::HttpStreamDestination) }
    let(:test_streamer) do
      dest = destination
      Class.new(described_class) do
        def streamable?
          true
        end

        define_method(:destinations) { [dest] }
      end
    end

    subject(:streamer_execute) { test_streamer.new(event_type, audit_event).execute }

    before do
      allow(AuditEvents::Streaming::Destinations::HttpStreamDestination)
        .to receive(:new)
        .and_return(http_streamer)
      allow(http_streamer).to receive(:stream)
    end

    context 'when not streamable' do
      before do
        instance = instance_double(described_class, streamable?: false, destinations: [destination], execute: nil)
        allow(test_streamer).to receive(:new).and_return(instance)
      end

      it 'does not stream to destinations' do
        expect(http_streamer).not_to receive(:stream)

        streamer_execute
      end
    end

    context 'when streamable' do
      specify do
        expect(http_streamer).to receive(:stream)

        streamer_execute
      end
    end
  end

  describe '#track_and_stream' do
    let(:destination) { build(:audit_events_group_external_streaming_destination, :http) }

    it 'tracks exception when error occurs' do
      allow(streamer).to receive(:track_audit_event).and_raise(StandardError)

      expect(Gitlab::ErrorTracking).to receive(:track_exception).with(instance_of(StandardError))

      streamer.send(:track_and_stream, destination)
    end
  end

  describe '#stream_to_destination' do
    let(:destination) { create(:audit_events_group_external_streaming_destination, :http) }
    let(:http_streamer) { instance_double(AuditEvents::Streaming::Destinations::HttpStreamDestination) }

    subject(:stream_to_destination) { streamer.send(:stream_to_destination, destination) }

    before do
      allow(AuditEvents::Streaming::Destinations::HttpStreamDestination)
        .to receive(:new)
        .and_return(http_streamer)
      allow(http_streamer).to receive(:stream)
    end

    context 'when destination category is valid' do
      it 'streams to destination', :aggregate_failures do
        expect(AuditEvents::Streaming::Destinations::HttpStreamDestination)
           .to receive(:new)
           .with(event_type, audit_event, destination)
        expect(http_streamer).to receive(:stream)

        stream_to_destination
      end
    end

    context 'when destination category is invalid' do
      before do
        allow(destination).to receive(:category).and_return('invalid')
      end

      it 'does not stream to destination' do
        expect { stream_to_destination }.to raise_error(ArgumentError, 'Streamer class for category not found')
      end
    end
  end

  describe '#track_audit_event', :aggregate_failures do
    subject(:track_audit_event) { streamer.send(:track_audit_event) }

    using RSpec::Parameterized::TableSyntax

    context 'with different audit operations' do
      where(:operation, :internal) do
        'delete_epic'       | true
        'delete_issue'      | true
        'project_created'   | false
        'unknown_operation' | false
      end
      with_them do
        let(:event_type) { operation }

        it 'tracks the event appropriately' do
          expectation = expect { track_audit_event }
          if internal
            expectation.to trigger_internal_events('trigger_audit_event')
              .with({ additional_properties: { label: operation } })
              .and increment_usage_metrics("counts.#{operation}")
          else
            expectation.not_to trigger_internal_events('trigger_audit_event')
          end
        end
      end
    end
  end
end
