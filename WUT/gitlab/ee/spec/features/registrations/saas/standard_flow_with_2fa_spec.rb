# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'SaaS registration from an invite', :with_current_organization, :js, :saas_registration, feature_category: :onboarding do
  include Features::TwoFactorHelpers

  context 'when user has not completed welcome step before being added to group', :sidekiq_inline do
    it 'registers the user, completes 2fa and sends them to the profile account page' do
      group = create_group
      password = User.random_password

      regular_sign_up(password: password)

      ensure_onboarding { expect_to_see_welcome_form }

      add_user_to_2fa_enforced_group(group)

      page.refresh

      expect_to_see_welcome_form_for_invites

      ensure_onboarding { expect_to_see_welcome_form_for_invites }

      fill_in_welcome_form(minimal: true) { expect_to_send_iterable_request(invite: true) }
      click_on 'Get started!'

      expect_to_be_on_2fa_verification(with_invite_notification: true)

      otp_authenticator_registration_and_copy_codes(user.current_otp, password)

      expect_to_be_on_profile_account_page
      ensure_onboarding_is_finished
    end

    context 'when user does not refresh the welcome page after being added to the group' do
      it 'registers the user, completes 2fa and sends them to the profile account page' do
        group = create_group
        password = User.random_password

        regular_sign_up(password: password)

        expect_to_see_welcome_form

        add_user_to_2fa_enforced_group(group)

        fill_in_welcome_form(minimal: false) { expect_to_send_iterable_request(invite: true) }
        click_on 'Continue'

        expect_to_be_on_2fa_verification(with_invite_notification: true)

        otp_authenticator_registration_and_copy_codes(user.current_otp, password)

        expect_to_be_on_profile_account_page
        ensure_onboarding_is_finished
      end
    end
  end

  context 'when user is past the welcome step before being added to group' do
    it 'registers the user, completes 2fa and sends them to the user account page' do
      group = create_group
      password = User.random_password

      regular_sign_up(password: password)

      ensure_onboarding { expect_to_see_welcome_form }

      fill_in_welcome_form(minimal: false)
      click_on 'Continue'

      ensure_onboarding { expect_to_see_company_form }

      add_user_to_2fa_enforced_group(group)

      page.refresh

      expect_to_be_on_2fa_verification

      otp_authenticator_registration_and_copy_codes(user.current_otp, password)

      expect_to_be_on_profile_account_page
      ensure_onboarding_is_finished
    end
  end

  def create_group
    create(:group, name: 'Test Group', require_two_factor_authentication: true, owners: [create(:user)])
  end

  def expect_to_see_welcome_form
    expect(page).to have_content('Welcome to GitLab, Registering!')

    page.within(welcome_form_selector) do
      expect(page).to have_content('Role')
      expect(page).to have_field('user_onboarding_status_role', valid: false)
      expect(page).to have_field('user_onboarding_status_setup_for_company_true', valid: false)
      expect(page).to have_content('I\'m signing up for GitLab because:')
      expect(page).to have_content('Who will be using GitLab?')
      expect(page)
        .to have_content(_('Enables a free Ultimate + GitLab Duo Enterprise trial when you create a new project.'))
      expect(page).to have_content('What would you like to do?')
      expect(page).not_to have_content('I\'d like to receive updates about GitLab via email')
    end
  end

  def expect_to_be_on_2fa_verification(with_invite_notification: false)
    expect(page).to have_content('Register a one-time password')

    return unless with_invite_notification # rubocop:disable RSpec/AvoidConditionalStatements

    expect(page)
      .to have_content('You have been granted access to the Test Group group with the following role: Developer.')
  end

  def expect_to_be_on_profile_account_page
    expect(page).to have_current_path(profile_account_path(two_factor_auth_enabled_successfully: true))
    expect(page).to have_content('You have set up 2FA for your account!')
  end

  def fill_in_welcome_form(minimal: true)
    select 'Software Developer', from: 'user_onboarding_status_role'
    select 'A different reason', from: 'user_onboarding_status_registration_objective'
    fill_in 'Why are you signing up? (optional)', with: 'My reason'

    yield if block_given? # rubocop:disable RSpec/AvoidConditionalStatements

    return if minimal # rubocop:disable RSpec/AvoidConditionalStatements

    choose 'My company or team'
    choose 'Create a new project'
  end

  def add_user_to_2fa_enforced_group(group)
    # Simulate adding a user through UI/API. The app only goes through the service below or the InviteCreateService.
    # This is cheaper than simulating full API posting which isn't necessary here to simulate our case.
    ::Members::CreateService
      .new(
        group.owners.first,
        user_id: user.id,
        access_level: Gitlab::Access::DEVELOPER,
        source: group,
        invite_source: 'test'
      ).execute
  end
end
