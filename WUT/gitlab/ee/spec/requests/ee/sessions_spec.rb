# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Sessions', feature_category: :system_access do
  include SessionHelpers

  let_it_be(:user) { create(:user, :with_namespace) }

  describe '.set_marketing_user_cookies', :saas do
    context 'when the gitlab_com_subscriptions saas feature is available' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      context 'when user signs in' do
        it 'sets marketing cookies' do
          post user_session_path(user: { login: user.username, password: user.password })

          expect(response.cookies['gitlab_user']).to be_present
          expect(response.cookies['gitlab_tier']).to be_present
        end

        context 'with multiple plans' do
          it 'sets marketing tier cookie with plan names' do
            create(:group_with_plan, plan: :free_plan, owners: user)
            create(:group_with_plan, plan: :ultimate_plan, owners: user)

            post user_session_path(user: { login: user.username, password: user.password })

            expect(response.cookies['gitlab_tier']).to eq 'free&ultimate'
          end
        end
      end

      context 'when user uses remember_me' do
        it 'sets the marketing cookies' do
          post user_session_path(user: { login: user.username, password: user.password, remember_me: true })

          expect(response.cookies['gitlab_user']).to be_present
          expect(response.cookies['gitlab_tier']).to be_present
        end
      end
    end

    context 'when the gitlab_com_subscriptions saas feature is not available' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      it 'does not set the marketing cookies' do
        post user_session_path(user: { login: user.username, password: user.password })

        expect(response.cookies['gitlab_user']).to be_nil
        expect(response.cookies['gitlab_tier']).to be_nil
      end
    end
  end

  describe '.unset_marketing_user_cookies', :saas do
    let(:cookie_domain) { ::Gitlab.config.gitlab.host }

    before do
      sign_in(user)
    end

    context 'when the gitlab_com_subscriptions saas feature is available' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      it 'unsets marketing cookies' do
        post destroy_user_session_path

        expect(response.cookies).to have_key('gitlab_user')
        expect(response.cookies).to have_key('gitlab_tier')

        expect(response.cookies['gitlab_user']).to be_nil
        expect(response.cookies['gitlab_tier']).to be_nil
      end
    end

    context 'when the gitlab_com_subscriptions saas feature is not available' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      it 'does not unset or modify the marketing cookies' do
        post destroy_user_session_path

        expect(response.cookies).not_to have_key('gitlab_user')
        expect(response.cookies).not_to have_key('gitlab_tier')
      end
    end
  end
end
