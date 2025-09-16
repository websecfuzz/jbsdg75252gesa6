# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Tracking::AiTracking, feature_category: :value_stream_management do
  # .track_event is tested in _old_approach_spec and _unified_approach_spec separately for now.

  describe '.track_user_activity' do
    let(:current_user) { create(:user) }

    it 'refreshes user metrics for last activity' do
      expect(Ai::UserMetrics).to receive(:refresh_last_activity_on).with(current_user).and_call_original

      described_class.track_user_activity(current_user)
    end
  end
end
