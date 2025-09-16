# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::PruneEventLogWorker, :geo, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  subject(:worker) { described_class.new }

  let_it_be(:primary) { create(:geo_node, :primary) }
  let_it_be(:secondary, refind: true) { create(:geo_node) }

  before do
    allow(Postgresql::ReplicationSlot)
      .to receive(:lag_too_great?)
      .and_return(false)
  end

  describe '#perform' do
    context 'current node secondary' do
      before do
        stub_current_geo_node(secondary)
      end

      it 'does nothing' do
        expect(Geo::PruneEventLogService).not_to receive(:new)

        worker.perform
      end
    end

    context 'current node primary' do
      before do
        stub_current_geo_node(primary)
      end

      it 'does nothing when database is not feeling healthy' do
        allow(Postgresql::ReplicationSlot)
          .to receive(:lag_too_great?)
          .and_return(true)

        expect(GeoNode).not_to receive(:secondary_nodes)
        expect(Geo::PruneEventLogService).not_to receive(:new)

        worker.perform
      end

      it 'does checks if it should prune' do
        expect(worker).to receive(:prune?)

        worker.perform
      end

      it 'deletes also associated event table rows' do
        create_list(:geo_event_log, 2, :geo_event)
        create(:geo_node_status, :healthy, cursor_last_event_id: Geo::EventLog.last.id, geo_node_id: secondary.id)

        expect { worker.perform }.to change { Geo::Event.count }.by(-1)
      end

      it 'delegates pruning to Geo::PruneEventLogService' do
        create(:geo_event_log, :geo_event)
        create(:geo_node_status, :healthy, cursor_last_event_id: Geo::EventLog.last.id, geo_node_id: secondary.id)

        prune_service = spy(:prune_service)

        expect(Geo::PruneEventLogService).to receive(:new).with(Geo::EventLog.last.id).and_return(prune_service)
        expect(prune_service).to receive(:execute)

        worker.perform
      end

      context 'no Geo secondary nodes' do
        before do
          secondary.destroy!
        end

        it 'deletes everything from the Geo event log' do
          create_list(:geo_event_log, 2)

          expect(Geo::PruneEventLogService).to receive(:new).with(:all).and_call_original

          worker.perform
        end

        context 'no Geo primary node' do
          before do
            primary.destroy!
          end

          it 'deletes everything from the Geo event log' do
            create_list(:geo_event_log, 2)

            expect(Geo::PruneEventLogService).to receive(:new).with(:all).and_call_original

            worker.perform
          end
        end
      end

      context 'multiple secondary nodes' do
        let_it_be(:secondary2) { create(:geo_node) }

        let!(:events) { create_list(:geo_event_log, 5, :geo_event) }

        it 'aborts when there is a node without status' do
          create(:geo_node_status, :healthy, cursor_last_event_id: events.last.id, geo_node_id: secondary.id)

          expect(worker).to receive(:log_info).with(/^Some nodes are not healthy/, unhealthy_node_count: 1)

          expect { worker.perform }.not_to change { Geo::EventLog.count }
        end

        it 'aborts when there is an unhealthy node' do
          create(:geo_node_status, :healthy, cursor_last_event_id: events.last.id, geo_node_id: secondary.id)
          create(:geo_node_status, :unhealthy, geo_node_id: secondary2.id)

          expect(worker).to receive(:log_info).with(/^Some nodes are not healthy/, unhealthy_node_count: 1)

          expect { worker.perform }.not_to change { Geo::EventLog.count }
        end

        it 'aborts when there is a node with an old status' do
          create(:geo_node_status, :healthy, cursor_last_event_id: events.last.id, geo_node_id: secondary.id)
          create(:geo_node_status, :healthy, geo_node_id: secondary2.id, last_successful_status_check_at: 61.minutes.ago)

          expect(worker).to receive(:log_info).with(/^Some nodes are not healthy/, unhealthy_node_count: 1)

          expect { worker.perform }.not_to change { Geo::EventLog.count }
        end

        it 'aborts when there is a node with a healthy status without timestamp' do
          create(:geo_node_status, :healthy, cursor_last_event_id: events.last.id, geo_node_id: secondary.id)
          create(:geo_node_status, :healthy, geo_node_id: secondary2.id, last_successful_status_check_at: nil)

          expect(worker).to receive(:log_info).with(/^Some nodes are not healthy/, unhealthy_node_count: 1)

          expect { worker.perform }.not_to change { Geo::EventLog.count }
        end

        it 'takes the integer-minimum value of all cursor_last_event_ids' do
          create(:geo_node_status, :healthy, cursor_last_event_id: events[3].id, geo_node_id: secondary.id)
          create(:geo_node_status, :healthy, cursor_last_event_id: events.last.id, geo_node_id: secondary2.id)
          expect(Geo::PruneEventLogService).to receive(:new).with(events[3].id).and_call_original

          expect { worker.perform }.to change { Geo::EventLog.count }.by(-3)
        end
      end
    end
  end

  describe '#log_error' do
    it 'calls the Geo logger' do
      expect(Gitlab::Geo::Logger).to receive(:error)

      worker.log_error('Something is wrong')
    end
  end
end
