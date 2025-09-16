# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'aiUserMetrics', :freeze_time, feature_category: :value_stream_management do
  include GraphqlHelpers

  let_it_be(:group) { create(:group, name: 'my-group') }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:add_on_purchase) do
    create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: group)
  end

  let_it_be(:current_user) do
    create(:user, reporter_of: group).tap do |user|
      create(:gitlab_subscription_user_add_on_assignment, user: user, add_on_purchase: add_on_purchase)
    end
  end

  let_it_be(:developer_without_enterprise_seat) do
    create(:user, developer_of: group)
  end

  let(:ai_user_metrics_fields) do
    query_nodes(:aiUserMetrics, fields, args: filter_params)
  end

  let(:filter_params) { {} }
  let(:expected_filters) { {} }

  shared_examples 'common ai metrics' do
    let(:fields) do
      ['codeSuggestionsAcceptedCount', 'duoChatInteractionsCount', 'user { id }']
    end

    let(:from) { '2024-05-01'.to_date }
    let(:to) { '2024-05-31'.to_date }
    let(:filter_params) { { startDate: from, endDate: to } }
    let(:expected_filters) { { from: from, to: to } }
    let(:service_payload) do
      { current_user.id => { code_suggestions_accepted_count: 1, duo_chat_interactions_count: 2 } }
    end

    before do
      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?)
                          .with(current_user, :read_enterprise_ai_analytics, anything)
                          .and_return(true)

      allow_next_instance_of(Analytics::AiAnalytics::AiUserMetricsService, current_user,
        hash_including(expected_filters)) do |instance|
        allow(instance).to receive(:execute).and_return(ServiceResponse.success(payload: service_payload))
      end

      post_graphql(query, current_user: current_user)
    end

    it 'returns all metrics' do
      expect(ai_user_metrics['nodes']).to eq([{
        'codeSuggestionsAcceptedCount' => 1,
        'duoChatInteractionsCount' => 2,
        'user' => { 'id' => current_user.to_global_id.to_s }
      }])
    end

    context 'without explicit filter range' do
      let(:filter_params) { {} }
      let(:expected_filters) { { from: Time.current.beginning_of_month, to: Time.current.end_of_month } }

      it 'uses current month' do
        expect(ai_user_metrics['nodes']).to eq([{
          'codeSuggestionsAcceptedCount' => 1,
          'duoChatInteractionsCount' => 2,
          'user' => { 'id' => current_user.to_global_id.to_s }
        }])
      end
    end

    context 'when filter range is too wide' do
      let(:filter_params) { { startDate: 5.years.ago } }

      it 'returns an error' do
        expect_graphql_errors_to_include("maximum date range is 1 year")
        expect(ai_user_metrics).to be_nil
      end
    end

    context 'with lastDuoActivityOn query', :freeze_time do
      let_it_be(:current_user_metrics) do
        create(:ai_user_metrics, last_duo_activity_on: 5.days.ago, user: current_user)
      end

      let(:fields) do
        ['user { id lastDuoActivityOn }']
      end

      it 'returns lastDuoActivityOn' do
        expect(ai_user_metrics['nodes']).to eq([{
          'user' => {
            'id' => current_user.to_global_id.to_s,
            'lastDuoActivityOn' => 5.days.ago.to_date.to_s
          }
        }])
      end
    end
  end

  context 'for group' do
    it_behaves_like 'common ai metrics' do
      let(:query) { graphql_query_for(:group, { fullPath: group.full_path }, ai_user_metrics_fields) }
      let(:ai_user_metrics) { graphql_data['group']['aiUserMetrics'] }
    end
  end

  context 'for project' do
    it_behaves_like 'common ai metrics' do
      let(:query) do
        graphql_query_for(:project, { fullPath: project.full_path }, ai_user_metrics_fields)
      end

      let(:ai_user_metrics) { graphql_data['project']['aiUserMetrics'] }
    end
  end
end
