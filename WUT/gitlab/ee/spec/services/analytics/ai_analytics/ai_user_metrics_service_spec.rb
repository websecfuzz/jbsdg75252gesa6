# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::AiAnalytics::AiUserMetricsService, feature_category: :value_stream_management do
  subject(:service_response) do
    described_class.new(current_user,
      namespace: container,
      from: from,
      to: to,
      user_ids: [user1.id, user2.id, user3.id]
    ).execute
  end

  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:project) { create(:project, group: subgroup) }
  let_it_be(:strange_namespace) { create(:project).reload.project_namespace }
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

  shared_examples 'common ai user metrics service' do
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
          expect(service_response.payload).to eq({})
        end
      end

      context 'with data' do
        before do
          clickhouse_fixture(:code_suggestion_events, [
            { user_id: user1.id, namespace_path: container.traversal_path, event: 3, timestamp: to - 3.days },
            { user_id: user1.id, namespace_path: container.traversal_path, event: 3,
              timestamp: to - 3.days + 1.second },
            { user_id: user1.id, namespace_path: strange_namespace.traversal_path, event: 3, timestamp: to - 4.days },
            { user_id: user2.id, namespace_path: container.traversal_path, event: 2, timestamp: to - 2.days },
            { user_id: user2.id, namespace_path: strange_namespace.traversal_path, event: 3, timestamp: to - 2.days },
            { user_id: stranger_user.id, namespace_path: strange_namespace.traversal_path, event: 2,
              timestamp: to - 2.days },
            { user_id: stranger_user.id, namespace_path: strange_namespace.traversal_path, event: 3,
              timestamp: to - 2.days + 1.second },
            { user_id: user3.id, namespace_path: container.traversal_path, event: 3, timestamp: to + 2.days },
            { user_id: user3.id, namespace_path: strange_namespace.traversal_path, event: 3, timestamp: from - 2.days }
          ])

          clickhouse_fixture(:duo_chat_events, [
            { user_id: user1.id, namespace_path: container.traversal_path, event: 1, timestamp: to - 3.days },
            { user_id: user1.id, namespace_path: strange_namespace.traversal_path, event: 1,
              timestamp: to - 3.days + 1.second },
            { user_id: user2.id, namespace_path: container.traversal_path, event: 1, timestamp: to - 2.days },
            { user_id: stranger_user.id, namespace_path: strange_namespace.traversal_path, event: 1,
              timestamp: to - 2.days },
            { user_id: stranger_user.id, namespace_path: strange_namespace.traversal_path, event: 1,
              timestamp: to - 2.days + 1.second },
            { user_id: user3.id, namespace_path: container.traversal_path, event: 1, timestamp: to + 2.days },
            { user_id: user3.id, namespace_path: strange_namespace.traversal_path, event: 1, timestamp: from - 2.days }
          ])
        end

        context 'when use_ai_events_namespace_path_filter feature flag is disabled' do
          before do
            stub_feature_flags(use_ai_events_namespace_path_filter: false)
          end

          it 'returns matched code contributors AI usage stats' do
            expect(service_response).to be_success
            expect(service_response.payload).to match({
              user1.id => { code_suggestions_accepted_count: 3, duo_chat_interactions_count: 2 },
              user2.id => { code_suggestions_accepted_count: 1, duo_chat_interactions_count: 1 }
            })
          end
        end

        context 'when use_ai_events_namespace_path_filter feature flag is enabled' do
          it 'returns matched code contributors AI usage stats' do
            expect(service_response).to be_success
            expect(service_response.payload).to match({
              user1.id => { code_suggestions_accepted_count: 2, duo_chat_interactions_count: 1 },
              user2.id => { duo_chat_interactions_count: 1 }
            })
          end
        end
      end
    end
  end

  context 'for group' do
    let_it_be(:container) { group }

    it_behaves_like 'common ai user metrics service'
  end

  context 'for project' do
    let_it_be(:container) { project.project_namespace.reload }

    it_behaves_like 'common ai user metrics service'
  end
end
