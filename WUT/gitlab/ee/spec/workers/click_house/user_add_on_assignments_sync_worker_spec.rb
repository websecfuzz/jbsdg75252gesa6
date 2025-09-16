# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ClickHouse::UserAddOnAssignmentsSyncWorker, :click_house, feature_category: :seat_cost_management do
  let(:worker) { described_class.new }

  subject(:perform) { worker.perform }

  context 'when ClickHouse is enabled for analytics' do
    before do
      stub_application_setting(use_clickhouse_for_analytics: true)
    end

    it 'calls sync service' do
      expect_next_instance_of(::ClickHouse::SyncStrategies::UserAddOnAssignmentSyncStrategy) do |sync_strategy|
        expect(sync_strategy).to receive(:execute)
      end

      perform
    end
  end

  context 'when ClickHouse is not enabled for analytics' do
    before do
      stub_application_setting(use_clickhouse_for_analytics: false)
    end

    it 'does not call sync service' do
      expect(::ClickHouse::SyncStrategies::UserAddOnAssignmentSyncStrategy).not_to receive(:new)

      perform
    end
  end
end
