# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ClickHouse::SyncStrategies::UserAddOnAssignmentSyncStrategy, feature_category: :value_stream_management do
  let(:strategy) { described_class.new }

  describe '#execute' do
    subject(:execute) { strategy.execute }

    before do
      stub_application_setting(use_clickhouse_for_analytics: true)
    end

    context 'when ClickHouse is enabled for analytics', :click_house do
      let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_pro) }
      # By creating these, papertrail generates UserAddOnAssignmentVersion records
      let!(:user_assignment_1) { create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_purchase) }
      let!(:user_assignment_2) { create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_purchase) }

      it 'correctly inserts all records' do
        user_assignment_1.destroy! # Creates a destroy event record

        expect(execute).to eq({ status: :processed, records_inserted: 3, reached_end_of_table: true })

        expected_records = [
          {
            'assignment_id' => user_assignment_1.id,
            'namespace_path' => add_on_purchase.namespace.traversal_path,
            'add_on_name' => 'code_suggestions',
            'user_id' => user_assignment_1.user_id,
            'purchase_id' => add_on_purchase.id,
            'assigned_at' => user_assignment_1.versions.first.created_at,
            'revoked_at' => user_assignment_1.versions.last.created_at
          },
          {
            'assignment_id' => user_assignment_2.id,
            'namespace_path' => add_on_purchase.namespace.traversal_path,
            'add_on_name' => 'code_suggestions',
            'user_id' => user_assignment_2.user_id,
            'purchase_id' => add_on_purchase.id,
            'assigned_at' => user_assignment_2.versions.first.created_at,
            'revoked_at' => nil
          }
        ]

        events =
          ClickHouse::Client.select(
            'SELECT * FROM user_add_on_assignments_history ORDER BY assignment_id',
            :main
          )

        expect(events).to include(*expected_records)
        # Three records are inserted, but two remains because
        # of ClickHouse table engine ReplacingMergeTree.
        expect(events.count).to eq(2)
      end

      context 'when ClickHouse is not enabled for analytics' do
        before do
          stub_application_setting(use_clickhouse_for_analytics: false)
        end

        context 'when the clickhouse database is configured the feature flag is enabled' do
          before do
            allow(Gitlab::ClickHouse).to receive(:configured?).and_return(true)
          end

          it 'returns empty response' do
            expect(execute).to eq({ status: :disabled })
          end
        end
      end
    end
  end
end
