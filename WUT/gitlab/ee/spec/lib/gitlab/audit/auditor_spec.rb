# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Audit::Auditor, feature_category: :audit_events do
  let(:name) { 'play_with_project_settings' }
  let_it_be(:author) { create(:user) }
  let_it_be_with_reload(:scope) { create(:group) }
  let(:target) { scope }
  let(:context) { { name: name, author: author, scope: scope, target: target } }
  let(:add_message) { 'Added an interesting field from project Gotham' }
  let(:remove_message) { 'Removed an interesting field from project Gotham' }
  let(:operation) do
    proc do
      ::Gitlab::Audit::EventQueue.push(add_message)
      ::Gitlab::Audit::EventQueue.push(remove_message)
    end
  end

  let(:logger) { instance_spy(Gitlab::AuditJsonLogger) }

  subject(:auditor) { described_class }

  before do
    allow(Gitlab::Audit::Type::Definition).to receive(:defined?).and_return(true)
    allow(Gitlab::Audit::Type::Definition).to receive(:defined?).with(name).and_return(true)
    stub_feature_flags(stream_audit_events_from_new_tables: false)
  end

  shared_examples 'only streamed' do
    before do
      allow(Gitlab::Audit::Type::Definition).to receive(:stream_only?).with(name).and_return(true)
    end

    it 'enqueues an event' do
      expect_any_instance_of(AuditEvent) do |event|
        expect(event).to receive(:stream_to_external_destinations).with(use_json: true, event_name: name)
      end

      audit!
    end

    it 'does not log audit events to file', :freeze_time do
      expect(::Gitlab::AuditJsonLogger).not_to receive(:build)

      audit!
    end

    it 'does not log audit events to database', :freeze_time do
      expect(AuditEvent).not_to receive(:bulk_insert!)

      audit!
    end
  end

  describe '.audit' do
    context 'when licensed' do
      before do
        stub_licensed_features(admin_audit_log: true, audit_events: true, extended_audit_events: true,
          external_audit_events: true)
      end

      shared_examples 'common audit event attributes' do |event_class, entity_type|
        let(:scope) { create(entity_type.to_sym) } # rubocop:disable Rails/SaveBang -- Need to ignore, create! masks factory failures
        let(:target) { scope }

        before do
          allow(Gitlab::Audit::Type::Definition).to receive(:defined?).and_return(true)

          AuditEvent.delete_all
          event_class.constantize.delete_all if event_class.present?
        end

        it "syncs audit event into #{event_class}" do
          audit!

          audit_events = AuditEvent.last(expected_count)
          created_audit_events = event_class.constantize.last(expected_count)

          expect(created_audit_events.size).to eq(expected_count)
          expect(audit_events.size).to eq(expected_count)

          expect(created_audit_events).to all(have_attributes(
            "#{entity_type}_id": scope.id,
            author_id: author.id,
            target_id: target.id,
            event_name: name,
            author_name: author.name,
            entity_path: scope.full_path,
            target_details: target.name,
            target_type: entity_type.capitalize
          ))
        end
      end

      shared_examples 'when audit event is invalid' do
        let(:scope) { Gitlab::Audit::InstanceScope.new }
        let(:target) { build_stubbed(:user) }

        before do
          allow(::AuditEvents::InstanceAuditEvent).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)
          allow(Gitlab::ErrorTracking).to receive(:track_exception)
        end

        it 'tracks error' do
          audit!

          expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(
            kind_of(ActiveRecord::RecordInvalid),
            { audit_operation: name }
          )
        end

        it 'does not throw exception' do
          expect { auditor.audit(context, &operation) }.not_to raise_exception
        end
      end

      context 'when recording multiple events', :request_store do
        let(:audit!) { auditor.audit(context, &operation) }

        context 'when the event is created within a transaction' do
          let_it_be(:scope) { create(:group) }
          let_it_be(:target) { create(:project) }

          before do
            scope.external_audit_event_destinations.create!(destination_url: 'http://example.com')
          end

          it 'does not raise Sidekiq::Worker::EnqueueFromTransactionError' do
            ApplicationRecord.transaction do
              expect { audit! }.not_to raise_error
            end
          end
        end

        it 'interacts with the event queue in correct order', :aggregate_failures do
          allow(Gitlab::Audit::EventQueue).to receive(:begin!).and_call_original
          allow(Gitlab::Audit::EventQueue).to receive(:end!).and_call_original

          audit!

          expect(Gitlab::Audit::EventQueue).to have_received(:begin!).ordered
          expect(Gitlab::Audit::EventQueue).to have_received(:end!).ordered
        end

        context 'for bulk insert' do
          before do
            allow(AuditEvent).to receive(:id_in).and_return([build_stubbed(:audit_event), build_stubbed(:audit_event)])
          end

          it 'bulk-inserts audit events to database' do
            expect(AuditEvent).to receive(:bulk_insert!).with(include(kind_of(AuditEvent)), returns: :ids)
            expect(AuditEvents::UserAuditEvent).to receive(:bulk_insert!)
              .with(include(kind_of(AuditEvents::UserAuditEvent)), returns: :ids)

            audit!
          end
        end

        it 'records audit events in correct order', :aggregate_failures do
          expect { audit! }.to change(AuditEvent, :count).by(2)

          event_messages = AuditEvent.order(:id).map { |event| event.details[:custom_message] }

          expect(event_messages).to eq([add_message, remove_message])
        end

        it 'logs audit events to database', :aggregate_failures do
          freeze_time do
            audit!

            audit_event = AuditEvent.last

            expect(audit_event.author_id).to eq(author.id)
            expect(audit_event.entity_id).to eq(scope.id)
            expect(audit_event.entity_type).to eq(scope.class.name)
            expect(audit_event.created_at).to eq(Time.zone.now)
            expect(audit_event.details[:target_id]).to eq(target.id)
            expect(audit_event.details[:target_type]).to eq(target.class.name)
          end
        end

        it 'logs audit events to file' do
          expect(::Gitlab::AuditJsonLogger).to receive(:build).and_return(logger)

          audit!

          expect(logger).to have_received(:info).exactly(2).times.with(
            hash_including(
              'id' => kind_of(Integer),
              'author_id' => author.id,
              'author_name' => author.name,
              'entity_id' => scope.id,
              'entity_type' => scope.class.name,
              'details' => kind_of(Hash)
            )
          )
        end

        it 'enqueues an event stream' do
          expect_any_instance_of(AuditEvent) do |event|
            expect(event).to receive(:stream_to_external_destinations).with(use_json: true, event_name: name)
          end

          audit!
        end

        context 'when overriding the create datetime' do
          let(:context) { { name: name, author: author, scope: scope, target: target, created_at: 3.weeks.ago } }

          it 'logs audit events to database', :freeze_time, :aggregate_failures do
            audit!

            audit_event = AuditEvent.last

            expect(audit_event.author_id).to eq(author.id)
            expect(audit_event.entity_id).to eq(scope.id)
            expect(audit_event.entity_type).to eq(scope.class.name)
            expect(audit_event.created_at).to eq(3.weeks.ago)
            expect(audit_event.details[:target_id]).to eq(target.id)
            expect(audit_event.details[:target_type]).to eq(target.class.name)
          end

          it 'logs audit events to file', :freeze_time do
            expect(::Gitlab::AuditJsonLogger).to receive(:build).and_return(logger)

            audit!

            expect(logger).to have_received(:info).exactly(2).times.with(
              hash_including(
                'author_id' => author.id,
                'author_name' => author.name,
                'entity_id' => scope.id,
                'entity_type' => scope.class.name,
                'details' => kind_of(Hash),
                'created_at' => 3.weeks.ago.iso8601(3)
              )
            )
          end
        end

        context 'when overriding the additional_details' do
          additional_details = { action: :custom, from: false, to: true }
          let(:context) do
            { name: name,
              author: author,
              scope: scope,
              target: target,
              created_at: Time.zone.now,
              additional_details: additional_details }
          end

          it 'logs audit events to database' do
            freeze_time do
              audit!

              expect(AuditEvent.last.details).to include(additional_details)
            end
          end

          it 'logs audit events to file', :freeze_time do
            expect(::Gitlab::AuditJsonLogger).to receive(:build).and_return(logger)

            audit!

            expect(logger).to have_received(:info).exactly(2).times.with(
              hash_including(
                'details' => hash_including('action' => 'custom', 'from' => 'false', 'to' => 'true'),
                'action' => 'custom',
                'from' => 'false',
                'to' => 'true'
              )
            )
          end
        end

        context 'when overriding the target_details' do
          target_details = "this is my target details"
          let(:context) do
            { name: name,
              author: author,
              scope: scope,
              target: target,
              created_at: Time.zone.now,
              target_details: target_details }
          end

          it 'logs audit events to database' do
            freeze_time do
              audit!

              audit_event = AuditEvent.last
              expect(audit_event.details).to include({ target_details: target_details })
              expect(audit_event.target_details).to eq(target_details)
            end
          end

          it 'logs audit events to file', :freeze_time do
            expect(::Gitlab::AuditJsonLogger).to receive(:build).and_return(logger)

            audit!

            expect(logger).to have_received(:info).exactly(2).times.with(
              hash_including(
                'details' => hash_including('target_details' => target_details),
                'target_details' => target_details
              )
            )
          end
        end

        context 'when overriding the ip address' do
          ip_address = '192.168.8.8'
          let(:context) { { name: name, author: author, scope: scope, target: target, ip_address: ip_address } }

          context 'when :admin_audit_log feature is available it logs ip address' do
            before do
              stub_licensed_features(admin_audit_log: true)
            end

            it 'logs audit events to database' do
              audit!

              expect(AuditEvent.last.ip_address).to eq(ip_address)
            end

            it 'logs audit events to file' do
              expect(::Gitlab::AuditJsonLogger).to receive(:build).and_return(logger)

              audit!

              expect(logger).to have_received(:info).exactly(2).times.with(
                hash_including('ip_address' => ip_address)
              )
            end

            context 'when :admin_audit_log feature is not available it does not log ip address', :freeze_time do
              before do
                stub_licensed_features(admin_audit_log: false)
              end

              it 'does not log audit event to database' do
                audit!

                expect(AuditEvent.last.ip_address).to be_nil
              end

              it 'does not log audit events to file' do
                expect(::Gitlab::AuditJsonLogger).to receive(:build).and_return(logger)

                audit!

                expect(logger).to have_received(:info).exactly(2).times.with(
                  hash_excluding(
                    'ip_address' => ip_address
                  )
                )
              end
            end
          end
        end

        context 'when event is only streamed' do
          let(:context) do
            { name: name, author: author, scope: scope, target: target, created_at: 3.weeks.ago, stream_only: true }
          end

          it_behaves_like 'only streamed'
        end

        context "when entity type is 'Project'" do
          let(:scope) { build_stubbed(:project) }
          let(:target) { scope }
          let(:expected_count) { 2 }

          it_behaves_like 'common audit event attributes', 'AuditEvents::ProjectAuditEvent', 'project'
        end

        context "when entity type is 'Group'" do
          let(:scope) { build_stubbed(:group) }
          let(:target) { scope }
          let(:expected_count) { 2 }

          it_behaves_like 'common audit event attributes', 'AuditEvents::GroupAuditEvent', 'group'
        end

        context "when entity type is 'User'" do
          let(:scope) { build_stubbed(:user) }
          let(:target) { scope }
          let(:expected_count) { 2 }

          it_behaves_like 'common audit event attributes', 'AuditEvents::UserAuditEvent', 'user'
        end

        context "when entity type is 'Gitlab::Audit::InstanceScope'" do
          let(:scope) { Gitlab::Audit::InstanceScope.new }
          let(:target) { build_stubbed(:user) }

          it 'syncs audit event into "AuditEvents::InstanceAuditEvent"', :aggregate_failures do
            expect { audit! }.to change { ::AuditEvents::InstanceAuditEvent.count }.by(2)

            created_audit_events = ::AuditEvents::InstanceAuditEvent.order(:id).limit(2)
            audit_events = AuditEvent.order(:id).limit(2)

            created_audit_events.zip(audit_events).each do |created_event, audit_event|
              expect(created_event).to have_attributes(
                id: audit_event.id,
                author_id: author.id,
                target_id: target.id,
                event_name: name,
                author_name: author.name,
                entity_path: "gitlab_instance",
                target_details: target.name,
                target_type: "User")
            end
          end
        end

        it_behaves_like 'when audit event is invalid' do
          before do
            allow(::AuditEvents::InstanceAuditEvent).to receive(:bulk_insert!).and_raise(ActiveRecord::RecordInvalid)
          end
        end
      end

      context 'when recording single event' do
        let(:audit!) { auditor.audit(context) }
        let(:context) do
          {
            name: name, author: author, scope: scope, target: target,
            message: 'Project has been deleted'
          }
        end

        shared_examples 'logs event to database' do
          it 'logs audit event to database', :aggregate_failures do
            expect { audit! }.to change(AuditEvent, :count).by(1)

            audit_event = AuditEvent.last

            expect(audit_event.author_id).to eq(author.id)
            expect(audit_event.entity_id).to eq(scope.id)
            expect(audit_event.entity_type).to eq(scope.class.name)
            expect(audit_event.details[:target_id]).to eq(target.id)
            expect(audit_event.details[:target_type]).to eq(target.class.name)
            expect(audit_event.details[:custom_message]).to eq('Project has been deleted')
          end
        end

        it_behaves_like 'logs event to database'

        context "when entity type is 'Project'" do
          let(:scope) { build_stubbed(:project) }
          let(:target) { scope }
          let(:expected_count) { 1 }

          it_behaves_like 'common audit event attributes', 'AuditEvents::ProjectAuditEvent', 'project'
        end

        context "when entity type is 'Group'" do
          let(:scope) { build_stubbed(:group) }
          let(:target) { scope }
          let(:expected_count) { 1 }

          it_behaves_like 'common audit event attributes', 'AuditEvents::GroupAuditEvent', 'group'
        end

        context "when entity type is 'User'" do
          let(:scope) { build_stubbed(:user) }
          let(:target) { scope }
          let(:expected_count) { 1 }

          it_behaves_like 'common audit event attributes', 'AuditEvents::UserAuditEvent', 'user'
        end

        context "when entity type is 'Gitlab::Audit::InstanceScope'" do
          let(:scope) { Gitlab::Audit::InstanceScope.new }
          let(:target) { build_stubbed(:user) }

          it 'syncs audit event into "AuditEvents::InstanceAuditEvent"', :aggregate_failures do
            expect { audit! }.to change { ::AuditEvents::InstanceAuditEvent.count }.by(1)

            expect(::AuditEvents::InstanceAuditEvent.last).to have_attributes(
              id: AuditEvent.last.id,
              author_id: author.id,
              target_id: target.id,
              event_name: name,
              author_name: author.name,
              entity_path: "gitlab_instance",
              target_details: target.name,
              target_type: "User"
            )
          end
        end

        it_behaves_like 'when audit event is invalid'

        it 'does not bulk insert and uses save to insert' do
          expect(AuditEvent).not_to receive(:bulk_insert!)
          expect_next_instance_of(AuditEvent) do |instance|
            expect(instance).to receive(:save!)
          end

          audit!
        end

        it 'logs audit events to file' do
          expect(::Gitlab::AuditJsonLogger).to receive(:build).and_return(logger)

          audit!

          expect(logger).to have_received(:info).once.with(
            hash_including(
              'id' => AuditEvent.last.id,
              'author_id' => author.id,
              'author_name' => author.name,
              'entity_id' => scope.id,
              'entity_type' => scope.class.name,
              'details' => kind_of(Hash),
              'custom_message' => 'Project has been deleted'
            )
          )
        end

        context 'when event is only streamed' do
          let(:context) do
            {
              name: name,
              author: author,
              scope: scope,
              target: target,
              created_at: 3.weeks.ago,
              stream_only: true,
              message: 'test'
            }
          end

          it_behaves_like 'only streamed'
        end

        context 'when the scope of event is instance' do
          let(:scope) { Gitlab::Audit::InstanceScope.new }

          let(:context) do
            {
              name: name,
              author: author,
              scope: scope,
              target: target,
              message: 'Project has been deleted'
            }
          end

          it_behaves_like 'logs event to database'
        end
      end

      context 'when audit events are invalid' do
        before do
          allow(AuditEvent).to receive(:bulk_insert!).and_raise(ActiveRecord::RecordInvalid)
          allow(Gitlab::ErrorTracking).to receive(:track_exception)
        end

        it 'tracks error' do
          auditor.audit(context, &operation)

          expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(
            kind_of(ActiveRecord::RecordInvalid),
            { audit_operation: name }
          )
        end

        it 'does not throw exception' do
          expect { auditor.audit(context, &operation) }.not_to raise_exception
        end
      end
    end

    context 'when unlicensed' do
      before do
        stub_licensed_features(admin_audit_log: false, audit_events: false, extended_audit_events: false)
      end

      let(:audit!) { auditor.audit(context, &operation) }

      it 'does not logs audit event to database' do
        expect { audit! }.not_to change { AuditEvent.count }
      end

      it 'does not logs audit events to file' do
        expect(::Gitlab::AuditJsonLogger).not_to receive(:build)

        audit!
      end

      context 'with operation' do
        let(:operation) do
          proc do
            'expected result'
          end
        end

        it 'returns operation result' do
          expect(audit!).to eq('expected result')
        end
      end

      context 'without an operation' do
        it 'returns nil' do
          expect(auditor.audit(context)).to be_nil
        end
      end
    end
  end

  describe '#audit_enabled?' do
    using RSpec::Parameterized::TableSyntax

    where(:admin_audit_log, :audit_events, :extended_audit_events, :result) do
      true  | false | false | true
      false | true  | false | true
      false | false | true  | true
      false | false | false | false
    end

    with_them do
      before do
        stub_licensed_features(
          admin_audit_log: admin_audit_log,
          audit_events: audit_events,
          extended_audit_events: extended_audit_events
        )
      end

      it 'returns the correct result when feature is available' do
        expect(auditor.new(context).audit_enabled?).to be(result)
      end
    end
  end

  describe '#log_events_and_stream' do
    let(:audit_event) { create(:audit_event, entity_id: group.id, entity_type: 'Group', author_id: author.id) }
    let(:events) { [audit_event] }
    let(:saved_events) { [audit_event] }
    let(:group) { create(:group) }

    let(:group_audit_event) do
      create(:audit_events_group_audit_event,
        author_id: author.id,
        target_group: group,
        group_id: group.id
      )
    end

    let(:new_audit_events) { [group_audit_event] }

    subject(:auditor) { described_class.new(context) }

    before do
      allow(Gitlab::Audit::Type::Definition).to receive(:defined?).and_return(true)
      allow(auditor).to receive(:log_authentication_event)
      allow(auditor).to receive(:log_to_file)
      allow(auditor).to receive_messages(log_to_new_tables: new_audit_events, log_to_database: saved_events)
    end

    context 'when feature flag :stream_audit_events_from_new_tables is enabled' do
      before do
        stub_feature_flags(stream_audit_events_from_new_tables: true)
      end

      it 'uses new audit events for streaming' do
        expect(auditor).to receive(:send_to_stream).with(new_audit_events)

        auditor.log_events_and_stream(events)
      end
    end

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(stream_audit_events_from_new_tables: false)
      end

      it 'uses saved events for streaming' do
        expect(auditor).to receive(:send_to_stream).with(saved_events)

        auditor.log_events_and_stream(events)
      end
    end

    describe '#determine_events_to_stream' do
      context 'when new audit events are present' do
        it 'returns filtered new events when feature flag is enabled' do
          stub_feature_flags(stream_audit_events_from_new_tables: true)

          expect(auditor).to receive(:filter_events_by_feature_flag).with(new_audit_events).and_return(new_audit_events)

          result = auditor.send(:determine_events_to_stream, new_audit_events, saved_events, events)

          expect(result).to eq(new_audit_events)
        end

        it 'returns saved events when feature flag is disabled' do
          stub_feature_flags(stream_audit_events_from_new_tables: false)

          expect(auditor).to receive(:filter_events_by_feature_flag).with(new_audit_events).and_return([])

          result = auditor.send(:determine_events_to_stream, new_audit_events, saved_events, events)

          expect(result).to eq(saved_events)
        end
      end

      context 'when new audit events are not present but saved events exist' do
        it 'returns saved events' do
          result = auditor.send(:determine_events_to_stream, [], saved_events, events)

          expect(result).to eq(saved_events)
        end
      end

      context 'when neither new nor saved events exist' do
        it 'returns original events' do
          result = auditor.send(:determine_events_to_stream, [], [], events)

          expect(result).to eq(events)
        end
      end
    end

    describe '#filter_events_by_feature_flag' do
      let(:instance_scope) { Gitlab::Audit::InstanceScope.new }
      let(:instance_audit_event) do
        build(:audit_events_instance_audit_event).tap do |event|
          allow(event).to receive(:entity).and_return(instance_scope)
        end
      end

      let(:mixed_events) { [group_audit_event, instance_audit_event] }

      it 'filters events based on feature flag for each entity' do
        stub_feature_flags(stream_audit_events_from_new_tables: group)

        result = auditor.send(:filter_events_by_feature_flag, mixed_events)

        expect(result).to include(group_audit_event)
        expect(result).not_to include(instance_audit_event)
      end
    end

    context 'for AuditEvents::ComplianceViolationScheduler' do
      before do
        allow(auditor).to receive(:log_to_new_tables).and_call_original
      end

      it 'calls AuditEvents::ComplianceViolationScheduler' do
        expect(AuditEvents::ComplianceViolationScheduler).to receive(:new).and_call_original

        auditor.log_events_and_stream(events)
      end
    end
  end
end
