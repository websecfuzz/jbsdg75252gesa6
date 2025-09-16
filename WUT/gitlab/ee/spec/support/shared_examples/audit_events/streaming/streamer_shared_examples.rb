# frozen_string_literal: true

RSpec.shared_examples 'streamer streaming audit events' do |scope|
  let_it_be(:group) { create(:group) if scope == :group }
  let_it_be(:audit_event) do
    scope == :group ? create(:audit_event, :group_event, target_group: group) : create(:audit_event, :instance_event)
  end

  let(:event_type) { 'event_type' }
  let(:streamer) { described_class.new(event_type, audit_event) }

  describe '#streamable?' do
    subject(:check_streamable) { streamer.streamable? }

    context 'when audit events licensed feature is false' do
      before do
        if scope == :group
          allow(audit_event.root_group_entity).to receive(:licensed_feature_available?)
            .with(:external_audit_events).and_return(false)
        else
          stub_licensed_features(external_audit_events: false)
        end
      end

      it { is_expected.to be_falsey }
    end

    context 'when audit events licensed feature is true' do
      before do
        if scope == :group
          allow(audit_event.root_group_entity).to receive(:licensed_feature_available?)
            .with(:external_audit_events).and_return(true)
        else
          stub_licensed_features(external_audit_events: true)
        end
      end

      context 'when audit event type is not valid for streaming' do
        before do
          if scope == :group
            create(:audit_events_group_external_streaming_destination, :http, group: audit_event.root_group_entity)
          else
            create(:audit_events_instance_external_streaming_destination, :http)
          end
        end

        it { is_expected.to be_truthy }
      end
    end
  end

  describe '#destinations' do
    subject(:get_streamer_destinations) { streamer.destinations }

    context 'when no valid destinations exist' do
      before do
        if scope == :group
          audit_event.root_group_entity.external_audit_event_streaming_destinations.update_all(active: false)
        else
          AuditEvents::Instance::ExternalStreamingDestination.update_all(active: false)
        end
      end

      it { is_expected.to be_empty }
    end

    context 'when some active destinations exist' do
      before do
        if scope == :group
          audit_event.root_group_entity.external_audit_event_streaming_destinations.update_all(active: false)
        else
          AuditEvents::Instance::ExternalStreamingDestination.update_all(active: false)
        end
      end

      let!(:destination) do
        if scope == :group
          group = audit_event.root_group_entity.reload
          create(:audit_events_group_external_streaming_destination, :http, group: group)
        else
          create(:audit_events_instance_external_streaming_destination, :http)
        end
      end

      it 'returns only the active destinations' do
        expect(get_streamer_destinations).to contain_exactly(destination)
        expect(destination.active).to be_truthy
      end
    end

    context 'when valid destinations exist' do
      before do
        audit_event.root_group_entity_id = group.id if scope == :group
      end

      let!(:destination) do
        if scope == :group
          group = audit_event.root_group_entity.reload
          create(:audit_events_group_external_streaming_destination, :http, group: group)
        else
          create(:audit_events_instance_external_streaming_destination, :http)
        end
      end

      it 'returns the correct destination' do
        expect(get_streamer_destinations).to contain_exactly(destination)
      end
    end
  end

  describe '#execute' do
    subject(:execute_streaming) { streamer.execute }

    context 'when streamable' do
      before do
        allow(streamer).to receive(:streamable?).and_return(true)
      end

      context 'when there are active destinations' do
        let(:active_destination1) do
          if scope == :group
            instance_double(AuditEvents::Group::ExternalStreamingDestination, category: 'http')
          else
            instance_double(AuditEvents::Instance::ExternalStreamingDestination, category: 'http')
          end
        end

        let(:active_destination2) do
          if scope == :group
            instance_double(AuditEvents::Group::ExternalStreamingDestination, category: 'gcp')
          else
            instance_double(AuditEvents::Instance::ExternalStreamingDestination, category: 'gcp')
          end
        end

        before do
          allow(streamer).to receive(:destinations).and_return([active_destination1, active_destination2])
        end

        it 'streams to all active destinations' do
          http_streamer = instance_double(AuditEvents::Streaming::Destinations::HttpStreamDestination)
          gcp_streamer = instance_double(AuditEvents::Streaming::Destinations::GoogleCloudLoggingStreamDestination)

          expect(AuditEvents::Streaming::Destinations::HttpStreamDestination)
            .to receive(:new)
            .with(event_type, audit_event, active_destination1)
            .and_return(http_streamer)

          expect(AuditEvents::Streaming::Destinations::GoogleCloudLoggingStreamDestination)
            .to receive(:new)
            .with(event_type, audit_event, active_destination2)
            .and_return(gcp_streamer)

          expect(http_streamer).to receive(:stream)
          expect(gcp_streamer).to receive(:stream)

          execute_streaming
        end

        context 'when one destination fails' do
          let(:active_destination1) do
            if scope == :group
              instance_double(AuditEvents::Group::ExternalStreamingDestination, category: 'http')
            else
              instance_double(AuditEvents::Instance::ExternalStreamingDestination, category: 'http')
            end
          end

          let(:active_destination2) do
            if scope == :group
              instance_double(AuditEvents::Group::ExternalStreamingDestination, category: 'gcp')
            else
              instance_double(AuditEvents::Instance::ExternalStreamingDestination, category: 'gcp')
            end
          end

          before do
            allow(streamer).to receive(:destinations).and_return([active_destination1, active_destination2])
          end

          it 'continues with other destinations and tracks the error' do
            failing_streamer = instance_double(AuditEvents::Streaming::Destinations::HttpStreamDestination)
            successful_streamer = instance_double(
              AuditEvents::Streaming::Destinations::GoogleCloudLoggingStreamDestination
            )

            expect(AuditEvents::Streaming::Destinations::HttpStreamDestination)
              .to receive(:new)
              .with(event_type, audit_event, active_destination1)
              .and_return(failing_streamer)

            expect(AuditEvents::Streaming::Destinations::GoogleCloudLoggingStreamDestination)
              .to receive(:new)
              .with(event_type, audit_event, active_destination2)
              .and_return(successful_streamer)

            expect(failing_streamer).to receive(:stream)
              .and_raise(StandardError, 'Network error')

            expect(successful_streamer).to receive(:stream)

            expect(Gitlab::ErrorTracking).to receive(:track_exception)
              .with(an_instance_of(StandardError))

            execute_streaming
          end
        end
      end

      context 'when destinations is empty' do
        before do
          allow(streamer).to receive(:destinations).and_return([])
        end

        it 'does not attempt any streaming' do
          expect(AuditEvents::Streaming::Destinations::HttpStreamDestination).not_to receive(:new)
          expect(AuditEvents::Streaming::Destinations::GoogleCloudLoggingStreamDestination).not_to receive(:new)
          expect(AuditEvents::Streaming::Destinations::AmazonS3StreamDestination).not_to receive(:new)

          execute_streaming
        end
      end
    end

    context 'when not streamable' do
      before do
        allow(streamer).to receive(:streamable?).and_return(false)
      end

      it 'does not execute streaming' do
        expect(streamer).not_to receive(:destinations)
        expect(AuditEvents::Streaming::Destinations::HttpStreamDestination).not_to receive(:new)

        execute_streaming
      end
    end
  end
end
