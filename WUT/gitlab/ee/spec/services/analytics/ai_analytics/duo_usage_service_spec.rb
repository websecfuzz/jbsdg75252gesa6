# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::AiAnalytics::DuoUsageService, feature_category: :value_stream_management do
  subject(:service_response) do
    described_class.new(current_user, namespace: container, from: from, to: to).execute
  end

  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:project) { create(:project, group: subgroup) }
  let_it_be(:project_namespace) { project.project_namespace.reload }
  let_it_be(:user1) { create(:user, developer_of: group) }
  let_it_be(:user2) { create(:user, developer_of: subgroup) }
  let_it_be(:user3) { create(:user, developer_of: group) }
  let_it_be(:stranger_user) { create(:user) }

  let(:current_user) { user1 }
  let(:from) { Time.current }
  let(:to) { Time.current }

  before do
    allow(Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(true)
  end

  shared_examples 'common duo usage service' do |flag_enabled|
    # This shared examples requires the following variables
    # :expected_results

    before do
      stub_feature_flags(fetch_contributions_data_from_new_tables: flag_enabled)
    end

    context 'when the clickhouse is not available for analytics' do
      before do
        allow(Gitlab::ClickHouse).to receive(:enabled_for_analytics?).with(container).and_return(false)
      end

      it 'returns service error' do
        expect(service_response).to be_error

        message = s_('AiAnalytics|the ClickHouse data store is not available')
        expect(service_response.message).to eq(message)
      end
    end

    context 'when the feature is available', :click_house, :freeze_time do
      let(:from) { 14.days.ago }
      let(:to) { 1.day.ago }

      context 'without data' do
        it 'returns 0' do
          expect(service_response).to be_success
          expect(service_response.payload).to eq({
            duo_used_count: 0
          })
        end
      end

      context 'with no selected fields' do
        it 'returns empty stats hash' do
          response = described_class.new(current_user,
            namespace: container,
            from: from,
            to: to,
            fields: []).execute

          expect(response).to be_success
          expect(response.payload).to eq({})
        end
      end

      context 'with data' do
        before do
          clickhouse_fixture(:duo_chat_events, [
            { user_id: user1.id, namespace_path: group.traversal_path, event: 1, timestamp: to - 3.days },
            { user_id: user1.id, namespace_path: subgroup.traversal_path, event: 1, timestamp: to - 4.days },
            { user_id: user2.id, namespace_path: project_namespace.traversal_path, event: 1, timestamp: to - 2.days },
            { user_id: user2.id, namespace_path: project_namespace.traversal_path, event: 1, timestamp: to - 2.days },
            # Included only when use_ai_events_namespace_path_filter is enabled
            { user_id: stranger_user.id, namespace_path: group.traversal_path, event: 1, timestamp: to - 2.days },
            # out of timeframe
            { user_id: user3.id, namespace_path: group.traversal_path, event: 1, timestamp: to + 2.days },
            # out of timeframe
            { user_id: user3.id, namespace_path: group.traversal_path, event: 1, timestamp: from - 2.days }
          ])

          clickhouse_fixture(:code_suggestion_events, [
            { user_id: user1.id, event: 2, timestamp: to - 3.days }, # shown
            { user_id: user1.id, event: 3, timestamp: to - 3.days + 1.second }, # accepted
            { user_id: user1.id, event: 2, timestamp: to - 4.days }, # shown
            { user_id: stranger_user.id, event: 2, timestamp: to - 2.days }, # shown
            { user_id: stranger_user.id, event: 3, timestamp: to - 2.days + 1.second }, # accepted
            { user_id: user3.id, event: 2, timestamp: to - 2.days }, # shown
            { user_id: user3.id, event: 2, timestamp: to - 2.days } # shown
          ])

          insert_events_into_click_house([
            build_stubbed(:event, :pushed, project: project, author: user1, created_at: to - 1.day),
            build_stubbed(:event, :commented, project: project, author: user1, created_at: to - 2.days),
            build_stubbed(:event, :pushed, project: project, author: user2, created_at: to - 1.day),
            build_stubbed(:event, :pushed, project: project, author: user3, created_at: to - 1.day)
          ])
        end

        it 'returns matched contributors duo usage stats' do
          expect(service_response).to be_success
          expect(service_response.payload).to match(expected_results)
        end
      end
    end
  end

  context 'when use_ai_events_namespace_path_filter feature flag is disabled' do
    let(:expected_results) { { duo_used_count: 3 } }

    before do
      stub_feature_flags(use_ai_events_namespace_path_filter: false)
    end

    context 'for group' do
      let_it_be(:container) { group }

      it_behaves_like 'common duo usage service', true

      context 'when fetch_contributions_data_from_new_tables feature flag is disabled' do
        it_behaves_like 'common duo usage service', false
      end
    end

    context 'for project' do
      let_it_be(:container) { project.project_namespace.reload }

      it_behaves_like 'common duo usage service', true

      context 'when fetch_contributions_data_from_new_tables feature flag is disabled' do
        it_behaves_like 'common duo usage service', false
      end
    end
  end

  context 'when use_ai_events_namespace_path_filter feature flag is enabled' do
    context 'for group' do
      let_it_be(:container) { group }

      let(:expected_results) { { duo_used_count: 3 } }

      # When use_ai_events_namespace_path_filter is enabled we do not need to
      # run this shared behavior with 'true' parameter because contributors filter won't be used
      it_behaves_like 'common duo usage service', false
    end

    context 'for project' do
      let_it_be(:container) { project.project_namespace.reload }

      let(:expected_results) { { duo_used_count: 1 } }

      # When use_ai_events_namespace_path_filter is enabled we do not need to
      # run this shared behavior with 'true' parameter because contributors filter won't be used
      it_behaves_like 'common duo usage service', false
    end
  end
end
