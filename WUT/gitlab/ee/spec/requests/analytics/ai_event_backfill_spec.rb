# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'AI events backfill', :freeze_time, :click_house, :sidekiq_inline,
  feature_category: :value_stream_management do
  include ApiHelpers
  include AdminModeHelper

  let_it_be(:organization) { create(:organization) }
  let_it_be(:duo_chat_event1) { create(:ai_duo_chat_event, timestamp: 3.days.ago, organization_id: organization.id) }
  let_it_be(:duo_chat_event2) { create(:ai_duo_chat_event, timestamp: 2.days.ago, organization_id: organization.id) }
  let_it_be(:code_suggestion_event1) do
    create(:ai_code_suggestion_event, timestamp: 3.days.ago, organization_id: organization.id)
  end

  let_it_be(:code_suggestion_event2) do
    create(:ai_code_suggestion_event, timestamp: 2.days.ago, organization_id: organization.id)
  end

  let_it_be(:current_user) { create(:admin, organizations: [organization]) }

  def events_in_ch(model)
    ClickHouse::Client.select("SELECT * FROM #{model.clickhouse_table_name} FINAL ORDER BY timestamp ASC", :main)
  end

  def change_analytics_in_ch_setting(enabled)
    put api("/application/settings", current_user), params: { use_clickhouse_for_analytics: enabled }
  end

  before do
    enable_admin_mode!(current_user)

    change_analytics_in_ch_setting(false)
  end

  context 'when ai_events_backfill_to_ch feature flag is disabled' do
    before do
      stub_feature_flags(ai_events_backfill_to_ch: false)
    end

    it 'does not add anything to clickhouse' do
      change_analytics_in_ch_setting(true)

      expect(events_in_ch(Ai::DuoChatEvent)).to be_empty
      expect(events_in_ch(Ai::CodeSuggestionEvent)).to be_empty
    end
  end

  context 'when ai_events_backfill_to_ch feature flag is enabled' do
    before do
      stub_feature_flags(ai_events_backfill_to_ch: true)
    end

    it 'adds records from PG to clickhouse' do
      change_analytics_in_ch_setting(true)

      expect(events_in_ch(Ai::DuoChatEvent).pluck('timestamp')).to eq([
        duo_chat_event1.timestamp,
        duo_chat_event2.timestamp
      ])
      expect(events_in_ch(Ai::CodeSuggestionEvent).pluck('timestamp')).to eq([
        code_suggestion_event1.timestamp,
        code_suggestion_event2.timestamp
      ])
    end
  end

  context 'when application setting is enabled twice' do
    before do
      stub_feature_flags(ai_events_backfill_to_ch: true)
    end

    it 'does not add duplicate records from PG to clickhouse twice' do
      change_analytics_in_ch_setting(true)

      expect(events_in_ch(Ai::DuoChatEvent).size).to eq(2)
      expect(events_in_ch(Ai::CodeSuggestionEvent).size).to eq(2)
      change_analytics_in_ch_setting(false)
      change_analytics_in_ch_setting(true)

      expect(events_in_ch(Ai::DuoChatEvent).size).to eq(2)
      expect(events_in_ch(Ai::CodeSuggestionEvent).size).to eq(2)
    end
  end

  context 'when different application setting was changed' do
    it 'does not add records from postgres to clickhouse' do
      put api("/application/settings", current_user), params: { max_pages_size: 100 }

      expect(events_in_ch(Ai::DuoChatEvent)).to be_empty
      expect(events_in_ch(Ai::CodeSuggestionEvent)).to be_empty
    end
  end

  context 'when application setting was already enabled' do
    before do
      stub_feature_flags(ai_events_backfill_to_ch: false)
      change_analytics_in_ch_setting(true)
      stub_feature_flags(ai_events_backfill_to_ch: true)
    end

    it 'does not add records from postgres to clickhouse' do
      change_analytics_in_ch_setting(true)

      expect(events_in_ch(Ai::DuoChatEvent)).to be_empty
      expect(events_in_ch(Ai::CodeSuggestionEvent)).to be_empty
    end
  end
end
