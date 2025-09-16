# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Trial Sign Up', :with_current_organization, :saas, feature_category: :acquisition do
  before do
    stub_application_setting(require_admin_approval_after_user_signup: false)
  end

  let_it_be(:new_user) { build_stubbed(:user) }

  describe 'on GitLab.com' do
    context 'with invalid email', :js do
      it_behaves_like 'user email validation' do
        let(:path) { new_user_registration_path }
      end
    end

    context 'with the unavailable username' do
      let(:existing_user) { create(:user) }

      it 'shows the error about existing username' do
        visit new_trial_registration_path
        click_on 'Continue'

        fill_in 'new_user_username', with: existing_user[:username]

        expect(page).to have_content('Username is already taken.')
      end
    end

    context 'when email is passed in the path', :js do
      it 'prefills the email form field' do
        visit new_trial_registration_path(email: 'foobar@email.com')

        expect(page).to have_field('Email', with: 'foobar@email.com')
      end
    end

    it_behaves_like 'creates a user with ArkoseLabs risk band' do
      let(:signup_path) { new_trial_registration_path }
      let(:user_email) { new_user.email }
      let(:fill_and_submit_signup_form) do
        fill_in_sign_up_form(new_user)
      end
    end

    context 'when reCAPTCHA is enabled', :js do
      before do
        stub_application_setting(recaptcha_enabled: true)
      end

      it 'creates the user' do
        visit new_trial_registration_path

        expect { fill_in_sign_up_form(new_user) }.to change { User.count }
      end

      context 'when reCAPTCHA verification fails' do
        before do
          allow_next_instance_of(TrialRegistrationsController) do |instance|
            allow(instance).to receive(:verify_recaptcha).and_return(false)
          end
        end

        it 'does not create the user' do
          visit new_trial_registration_path

          expect { fill_in_sign_up_form(new_user) }.not_to change { User.count }
          expect(page).to have_content(_('There was an error with the reCAPTCHA. Please solve the reCAPTCHA again.'))
        end
      end
    end

    context 'when experiment `lightweight_trial_registration_redesign` is candidate', :js do
      include IdentityVerificationHelpers

      let(:user_email) { new_user.email }

      before do
        stub_application_setting_enum('email_confirmation_setting', 'hard')
        stub_experiments(lightweight_trial_registration_redesign: :candidate)
      end

      it 'goes through the experiment trial registration flow' do
        visit new_trial_registration_path

        # Step 1
        expect(page).to have_content('Get Started with GitLab')
        expect(page).not_to have_content('First name')
        expect(page).not_to have_content('Last name')

        fill_in 'new_user_username', with: new_user.username
        fill_in 'new_user_email', with: new_user.email
        fill_in 'new_user_password', with: new_user.password

        click_button _('Continue')

        # Step 2
        expect(page).to have_content('Help us keep GitLab secure')
        expect(page).not_to have_content('You are signed in as')

        fill_in 'verification_code', with: email_verification_code

        click_button _('Verify email address')

        # Step 3
        expect(page).to have_content('Verification successful')

        wait_for_all_requests

        # Step 4
        # To be updated once Step 4 is completed in https://gitlab.com/gitlab-org/gitlab/-/issues/550313
        expect(page).to have_content('Welcome to GitLab')
      end
    end
  end
end
