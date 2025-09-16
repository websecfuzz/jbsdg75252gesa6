# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::MetricsUpdateService, :geo, :prometheus, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  let_it_be(:primary) { create(:geo_node, :primary) }
  let_it_be(:secondary) { create(:geo_node) }
  let_it_be(:another_secondary) { create(:geo_node) }

  subject { described_class.new }

  let(:event_date) { Time.current.utc }

  let(:data) do
    {
      status_message: nil,
      db_replication_lag_seconds: 0,
      project_repositories_count: 10,
      last_event_id: 2,
      last_event_date: event_date,
      cursor_last_event_id: 1,
      cursor_last_event_date: event_date,
      event_log_max_id: 555,
      project_repositories_registry_count: 10,
      project_repositories_checksummed_count: 3,
      project_repositories_checksum_failed_count: 4,
      project_repositories_synced_count: 5,
      project_repositories_failed_count: 6,
      project_repositories_verified_count: 7,
      project_repositories_verification_failed_count: 8
    }
  end

  let(:primary_data) do
    {
      status_message: nil,
      project_repositories_count: 10,
      last_event_id: 2,
      last_event_date: event_date,
      event_log_max_id: 555
    }
  end

  before do
    # We disable the transaction_open? check because Gitlab::Database::BatchCounter.batch_count
    # is not allowed within a transaction but all RSpec tests run inside of a transaction.
    stub_batch_counter_transaction_open_check

    allow(Gitlab::Metrics).to receive(:prometheus_metrics_enabled?).and_return(true)
  end

  describe '#execute' do
    before do
      allow_any_instance_of(Geo::NodeStatusRequestService).to receive(:execute).and_return(true)
    end

    context 'when called from metrics worker' do
      let(:timeout) { 1.hour }

      before do
        stub_current_geo_node(primary)
        allow(GeoNodeStatus).to receive(:current_node_status)
      end

      it 'passes timing parameters to GeoNodeStatus' do
        subject.execute(
          timeout:
        )

        expect(GeoNodeStatus).to have_received(:current_node_status).with(timeout:).once
      end
    end

    context 'when current node is nil' do
      before do
        stub_current_geo_node(nil)
      end

      it 'skips posting the status' do
        expect_any_instance_of(Geo::NodeStatusRequestService).not_to receive(:execute)

        subject.execute
      end
    end

    context 'when node is the primary' do
      before do
        stub_current_geo_node(primary)
      end

      it 'calls GeoNodeStatus without timing parameters by default' do
        allow(GeoNodeStatus).to receive(:current_node_status)

        subject.execute

        expect(GeoNodeStatus).to have_received(:current_node_status).with(timeout: nil).once
      end

      it 'updates the cache' do
        status = GeoNodeStatus.new(primary_data)
        allow(GeoNodeStatus).to receive(:current_node_status).and_return(status)

        expect(status).to receive(:update_cache!)

        subject.execute
      end

      it 'updates metrics for all sites', quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/548147' do
        allow(GeoNodeStatus).to receive(:current_node_status).and_return(GeoNodeStatus.new(primary_data))

        secondary.update!(status: GeoNodeStatus.new(data))
        another_secondary.update!(status: GeoNodeStatus.new(data))

        subject.execute

        expect(metric_value(:geo_repositories, geo_site: secondary)).to eq(10)
        expect(metric_value(:geo_repositories, geo_site: another_secondary)).to eq(10)
        expect(metric_value(:geo_repositories, geo_site: primary)).to eq(10)
      end

      it 'updates the GeoNodeStatus entry' do
        expect { subject.execute }.to change { GeoNodeStatus.count }.by(1)
      end
    end

    context 'when node is a secondary' do
      before do
        stub_current_geo_node(secondary)
        @status = GeoNodeStatus.new(data)
        allow(GeoNodeStatus).to receive(:current_node_status).and_return(@status)
      end

      it 'updates the cache' do
        expect(@status).to receive(:update_cache!)

        subject.execute
      end

      it 'adds gauges for various metrics' do
        subject.execute

        expect(metric_value(:geo_db_replication_lag_seconds)).to eq(0)
        expect(metric_value(:geo_last_event_id)).to eq(2)
        expect(metric_value(:geo_last_event_timestamp)).to eq(event_date.to_i)
        expect(metric_value(:geo_cursor_last_event_id)).to eq(1)
        expect(metric_value(:geo_cursor_last_event_timestamp)).to eq(event_date.to_i)
        expect(metric_value(:geo_last_successful_status_check_timestamp)).to be_truthy
        expect(metric_value(:geo_event_log_max_id)).to eq(555)

        expect(metric_value(:geo_repositories)).to eq(10)
        expect(metric_value(:geo_project_repositories)).to eq(10)
        expect(metric_value(:geo_project_repositories_registry)).to eq(10)
        expect(metric_value(:geo_project_repositories_checksummed)).to eq(3)
        expect(metric_value(:geo_project_repositories_checksum_failed)).to eq(4)
        expect(metric_value(:geo_project_repositories_synced)).to eq(5)
        expect(metric_value(:geo_project_repositories_failed)).to eq(6)
        expect(metric_value(:geo_project_repositories_verified)).to eq(7)
        expect(metric_value(:geo_project_repositories_verification_failed)).to eq(8)
      end

      it 'increments a counter when metrics fail to retrieve' do
        allow_next_instance_of(Geo::NodeStatusRequestService) do |instance|
          allow(instance).to receive(:execute).and_return(false)
        end

        # Run once to get the gauge set
        subject.execute

        expect { subject.execute }.to change { metric_value(:geo_status_failed_total) }.by(1)
      end

      it 'does not create GeoNodeStatus entries' do
        expect { subject.execute }.to not_change { GeoNodeStatus.count }
      end
    end

    def metric_value(metric_name, geo_site: secondary)
      Gitlab::Metrics.client.get(metric_name)&.get({ name: geo_site.name, url: geo_site.name })
    end
  end

  describe '#current_node_status' do
    context 'when called with a timeout' do
      let(:timeout) { 1.hour }

      it 'calls GeoNodeStatus.current_node_status with the provided timeout' do
        allow(GeoNodeStatus).to receive(:current_node_status).and_return(nil)

        subject.send(:current_node_status, timeout: timeout)

        expect(GeoNodeStatus).to have_received(:current_node_status).with(timeout: timeout).once
      end
    end

    context 'when called without a timeout' do
      it 'calls GeoNodeStatus.current_node_status with nil timeout' do
        allow(GeoNodeStatus).to receive(:current_node_status).and_return(nil)

        subject.send(:current_node_status)

        expect(GeoNodeStatus).to have_received(:current_node_status).with(timeout: nil).once
      end
    end
  end
end
