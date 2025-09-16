# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ClickHouse::SyncStrategies::UserAddonAssignmentVersionsSyncStrategy, :click_house, feature_category: :value_stream_management do
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

      def fetch_aggregated_events
        ClickHouse::Client.select(
          <<~SQL,
            SELECT
              assignment_id,
              namespace_path,
              add_on_name,
              user_id,
              purchase_id,
              minMerge(assigned_at) as assigned_at,
              maxMerge(revoked_at) as revoked_at
            FROM user_addon_assignments_history
            GROUP BY assignment_id, namespace_path, add_on_name, user_id, purchase_id
            ORDER BY assignment_id
          SQL
          :main
        )
      end

      def fetch_raw_events
        ClickHouse::Client.select(
          'SELECT * FROM subscription_user_add_on_assignment_versions ORDER BY id',
          :main
        )
      end

      def verify_assignment_in_clickhouse(assignment, expected_assigned_at, expected_revoked_at = nil)
        event = fetch_aggregated_events.find { |e| e['assignment_id'] == assignment.id }

        expect(event).not_to be_nil
        expect(event['namespace_path']).to eq(assignment.add_on_purchase.namespace.traversal_path)
        expect(event['add_on_name']).to eq('code_suggestions')
        expect(event['user_id']).to eq(assignment.user_id)
        expect(event['purchase_id']).to eq(assignment.add_on_purchase.id)

        expect(event['assigned_at']).to be_within(1.second).of(expected_assigned_at)

        if expected_revoked_at
          expect(event['revoked_at']).to be_within(1.second).of(expected_revoked_at)
        else
          expect(event['revoked_at']).to be_nil
        end
      end

      it 'returns custom cursor identifier' do
        expect(strategy.send(:sync_cursor_identifier)).to eq('user_addon_assignment_versions')
      end

      it 'correctly inserts all records' do
        user_assignment_1.destroy! # Creates a destroy event record

        expect(execute).to eq({ status: :processed, records_inserted: 3, reached_end_of_table: true })

        raw_events = fetch_raw_events
        aggregated_events = fetch_aggregated_events

        expect(raw_events.count).to eq(3)
        expect(aggregated_events.count).to eq(2)

        verify_assignment_in_clickhouse(
          user_assignment_1,
          user_assignment_1.versions.first.created_at,
          user_assignment_1.versions.last.created_at
        )

        verify_assignment_in_clickhouse(
          user_assignment_2,
          user_assignment_2.versions.first.created_at,
          nil # not revoked
        )

        sync_cursor_result = ClickHouse::Client.select(
          "SELECT * FROM sync_cursors LIMIT 1 ", :main).first

        expect(sync_cursor_result).to include(
          "primary_key_value" => raw_events.last['id'],
          "table_name" => 'user_addon_assignment_versions'
        )
      end

      context 'when checking data integrity' do
        it 'preserves all fields correctly in raw events table' do
          user_assignment_1.destroy! # Creates a destroy event

          execute

          raw_events = fetch_raw_events
          original_versions = ::GitlabSubscriptions::UserAddOnAssignmentVersion.order(:id)

          expect(raw_events.size).to eq(original_versions.size)

          raw_events.each_with_index do |raw_event, index|
            original_version = original_versions[index]

            expect(raw_event['id']).to eq(original_version.id)
            expect(raw_event['organization_id']).to eq(original_version.organization_id)
            expect(raw_event['item_id']).to eq(original_version.item_id)
            expect(raw_event['user_id']).to eq(original_version.user_id)
            expect(raw_event['purchase_id']).to eq(original_version.purchase_id)
            expect(raw_event['namespace_path']).to eq(original_version.namespace_path)
            expect(raw_event['add_on_name']).to eq(original_version.add_on_name)
            expect(raw_event['event']).to eq(original_version.event)
            expect(raw_event['created_at']).to eq(original_version.created_at)
          end
        end

        it 'correctly aggregates data in history table' do
          user_assignment_1.destroy!

          execute

          aggregated_events = fetch_aggregated_events

          assignment_1_aggregated = aggregated_events.find { |e| e['assignment_id'] == user_assignment_1.id }
          assignment_2_aggregated = aggregated_events.find { |e| e['assignment_id'] == user_assignment_2.id }

          # Assignment 1 should have both assigned and revoked times
          expect(assignment_1_aggregated).to include(
            'assignment_id' => user_assignment_1.id,
            'namespace_path' => add_on_purchase.namespace.traversal_path,
            'add_on_name' => 'code_suggestions',
            'user_id' => user_assignment_1.user_id,
            'purchase_id' => add_on_purchase.id
          )
          expect(assignment_1_aggregated['assigned_at']).not_to be_nil
          expect(assignment_1_aggregated['revoked_at']).not_to be_nil

          # Assignment 2 should only have assigned time
          expect(assignment_2_aggregated).to include(
            'assignment_id' => user_assignment_2.id,
            'namespace_path' => add_on_purchase.namespace.traversal_path,
            'add_on_name' => 'code_suggestions',
            'user_id' => user_assignment_2.user_id,
            'purchase_id' => add_on_purchase.id
          )
          expect(assignment_2_aggregated['assigned_at']).not_to be_nil
          expect(assignment_2_aggregated['revoked_at']).to be_nil
        end
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
