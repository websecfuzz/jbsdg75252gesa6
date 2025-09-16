# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PersonalAccessTokens::RotateService, feature_category: :system_access do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:token, reload: true) { create(:personal_access_token) }

  subject(:response) { described_class.new(token.user, token).execute }

  context 'when target user is a service account' do
    let_it_be(:service_account) { create(:user, :service_account) }
    let_it_be(:service_token, reload: true) { create(:personal_access_token, user: service_account) }

    context 'when expires_at is nil', time_travel_to: '2024-08-24' do
      let(:params) { { expires_at: nil } }

      subject(:response) { described_class.new(service_account, service_token, nil, params).execute }

      where(:require_token_expiry, :require_token_expiry_for_service_accounts, :expires_at) do
        true | true | Date.new(2024, 8, 31) # 1 week from now
        true | false | nil
        false | true | Date.new(2024, 8, 31) # 1 week from now
        false | false | nil
      end

      with_them do
        before do
          stub_application_setting(require_personal_access_token_expiry: require_token_expiry)
          stub_licensed_features(service_accounts: true)
          stub_ee_application_setting(
            service_access_tokens_expiration_enforced: require_token_expiry_for_service_accounts)
        end

        it "rotates user's own token" do
          expect(response).to be_success

          new_token = response.payload[:personal_access_token]

          expect(new_token.token).not_to eq(service_token.token)
          expect(new_token.expires_at).to eq(expires_at)
          expect(new_token.user).to eq(service_account)
        end
      end
    end
  end

  context 'when max lifetime is set to less than 1 week', :freeze_time do
    before do
      allow(Gitlab::CurrentSettings).to receive(:max_personal_access_token_lifetime_from_now)
        .and_return(2.days.from_now)
    end

    let_it_be(:token, reload: true) { create(:personal_access_token) }

    subject(:response) { described_class.new(token.user, token).execute }

    it "rotates user's own token" do
      expect(response).to be_success

      new_token = response.payload[:personal_access_token]

      expect(new_token.token).not_to eq(token.token)
      expect(new_token.expires_at).to eq(Date.current + 2.days)
      expect(new_token.user).to eq(token.user)
    end
  end

  context 'when max lifetime is set to more than 1 week' do
    before do
      allow(Gitlab::CurrentSettings).to receive(:max_personal_access_token_lifetime_from_now)
        .and_return(10.days.from_now)
    end

    let_it_be(:token, reload: true) { create(:personal_access_token) }

    subject(:response) { described_class.new(token.user, token).execute }

    it "rotates user's own token", :freeze_time do
      expect(response).to be_success

      new_token = response.payload[:personal_access_token]

      expect(new_token.token).not_to eq(token.token)
      expect(new_token.expires_at).not_to eq(Date.current + 10.days)
      expect(new_token.expires_at).to eq(Date.current + 7.days)
      expect(new_token.user).to eq(token.user)
    end
  end
end
