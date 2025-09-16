# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::CodeSuggestionsEventsBackfillWorker, feature_category: :value_stream_management do
  let_it_be(:user) { create(:user, :with_organization) }

  it_behaves_like 'common ai usage backfill worker', Ai::CodeSuggestionEvent do
    let!(:pg_events) do
      [
        create(:ai_code_suggestion_event, user: user, timestamp: 1.day.ago),
        create(:ai_code_suggestion_event, user: user, timestamp: 2.days.ago),
        create(:ai_code_suggestion_event, user: user, timestamp: 3.days.ago)
      ]
    end

    let(:expected_ch_events) do
      pg_events.map do |e|
        {
          user_id: e.user_id,
          timestamp: e.timestamp,
          event: Ai::CodeSuggestionEvent.events['code_suggestion_shown_in_ide'],
          language: 'ruby',
          suggestion_size: 1,
          unique_tracking_id: e.payload['unique_tracking_id'],
          branch_name: 'main',
          namespace_path: '0/'
        }.stringify_keys
      end
    end

    let(:existing_ch_records) do
      clickhouse_fixture(:code_suggestion_events, [
        { user_id: pg_events.first.user.id, event: 2, timestamp: pg_events.first.timestamp }, # duplicate
        { user_id: pg_events.first.user.id, event: 2, timestamp: pg_events.first.timestamp - 10.days }
      ])
    end
  end
end
