# frozen_string_literal: true

require "spec_helper"

RSpec.describe EE::AccessTokensHelper do
  describe '#expires_at_field_data', :freeze_time do
    before do
      allow(helper).to receive_messages(
        personal_access_token_expiration_policy_enabled?: true, # The `false` condition is tested in the CE test.
        personal_access_token_max_expiry_date: Time.new(2022, 3, 2, 10, 30, 45, 'UTC')
      )
    end

    it 'returns expected hash' do
      expect(helper.expires_at_field_data).to eq({
        min_date: 1.day.from_now.iso8601,
        max_date: '2022-03-02T10:30:45Z'
      })
    end
  end
end
