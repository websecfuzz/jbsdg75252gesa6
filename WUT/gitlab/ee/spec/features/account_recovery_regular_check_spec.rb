# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Account recovery regular check callout', feature_category: :user_management do
  include Features::TwoFactorHelpers

  context 'when signed in' do
    let(:user_two_factor_disabled) { create(:user) }
    let(:user_two_factor_enabled) { create(:user, :two_factor) }
    let(:message) { 'Ensure you have two-factor authentication recovery codes stored in a safe place.' }
    let(:action_button) { 'Manage two-factor authentication' }

    before do
      allow(Gitlab).to receive(:com?).and_return(true)
    end

    context 'when user has two-factor authentication disabled' do
      before do
        sign_in(user_two_factor_disabled)
      end

      it 'does not show the callout' do
        visit dashboard_todos_path

        expect(page).not_to have_content(message)
      end

      context 'when user sets up two-factor authentication' do
        it 'does not show the callout', :js do
          visit profile_two_factor_auth_path

          otp_authenticator_registration_and_copy_codes(user_two_factor_disabled.reload.current_otp,
            user_two_factor_disabled.password)

          visit dashboard_todos_path

          expect(page).not_to have_content(message)
        end
      end
    end

    context 'when user has two-factor authentication enabled' do
      before do
        sign_in(user_two_factor_enabled)
      end

      it 'shows callout if not dismissed' do
        visit dashboard_todos_path

        expect(page).to have_content(message)
        expect(page).to have_link(action_button, href: profile_two_factor_auth_path)
      end

      it 'hides callout when user clicks action button', :js do
        visit dashboard_todos_path

        expect(page).to have_content(message)

        click_link action_button
        wait_for_requests

        expect(page).not_to have_content(message)
      end

      it 'hides callout when user clicks close', :js do
        visit dashboard_todos_path

        expect(page).to have_content(message)

        close_callout

        expect(page).not_to have_content(message)
      end

      it 'shows callout on next session if user did not dismissed it', :js do
        visit dashboard_todos_path

        expect(page).to have_content(message)

        start_new_session(user_two_factor_enabled)
        visit dashboard_todos_path

        expect(page).to have_content(message)
      end

      it 'hides callout on next session if user dismissed it', :js,
        quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/449085' do
        visit dashboard_todos_path

        expect(page).to have_content(message)

        close_callout

        start_new_session(user_two_factor_enabled)
        visit dashboard_todos_path

        wait_for_requests
        expect(page).to have_no_content(message)
      end
    end
  end

  def close_callout
    find_by_testid('close-account-recovery-regular-check-callout').click
    wait_for_requests
  end

  def start_new_session(user)
    gitlab_sign_out
    gitlab_sign_in(user, two_factor_auth: true)
  end
end
