# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::DuoChatEventsBackfillWorker, feature_category: :value_stream_management do
  it_behaves_like 'common ai usage backfill worker', Ai::DuoChatEvent do
    let(:user) { create(:user, :with_organization, :with_namespace) }

    let!(:pg_events) do
      [
        create(:ai_duo_chat_event, user: user, timestamp: 1.day.ago),
        create(:ai_duo_chat_event, user: user, timestamp: 2.days.ago),
        create(:ai_duo_chat_event, user: user, timestamp: 3.days.ago)
      ]
    end

    let(:expected_ch_events) do
      pg_events.map do |e|
        {
          user_id: e.user_id,
          timestamp: e.timestamp,
          event: Ai::DuoChatEvent.events['request_duo_chat_response'],
          namespace_path: '0/'
        }.stringify_keys
      end
    end

    let(:existing_ch_records) do
      clickhouse_fixture(:duo_chat_events, [
        { user_id: pg_events.first.user.id, event: 1, timestamp: pg_events.first.timestamp }, # duplicate
        { user_id: pg_events.first.user.id, event: 1, timestamp: pg_events.first.timestamp - 10.days }
      ])
    end
  end
end
