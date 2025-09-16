# frozen_string_literal: true

require_relative 'subscription_portal_helpers'
require 'support/helpers/email_helpers'

module SaasRegistrationHelpers
  include IdentityVerificationHelpers
  include SubscriptionPortalHelpers
  include EmailHelpers

  def user
    User.find_by(email: user_email)
  end

  def user_email
    'onboardinguser@example.com'
  end

  def user_signs_in(password: User.random_password)
    user.update!(password: password)

    fill_in 'Password', with: password

    wait_for_all_requests

    click_button 'Sign in'
  end

  def expect_to_see_account_confirmation_page
    expect(page).to have_content('Help us keep GitLab secure')
    expect(page).to have_content('Verify email address')
  end

  def expect_to_see_welcome_form_for_invites
    expect(page).to have_content('Welcome to GitLab, Registering!')

    page.within(welcome_form_selector) do
      expect(page).not_to have_content('What would you like to do?')
    end
  end

  def expect_to_be_on_page_for(group)
    expect(page).to have_current_path(group_path(group), ignore_query: true)
    expect(page)
      .to have_content('You have been granted access to the Test Group group with the following role: Developer')
  end

  def confirm_account
    verify_code(confirmation_code)

    expect_verification_completed
  end

  def accept_privacy_and_terms
    checkbox = find('[data-testid="privacy-and-terms-confirm"] > input')

    expect(checkbox).not_to be_checked

    checkbox.set(true)
  end

  def regular_sign_up(params = {}, password: User.random_password)
    perform_enqueued_jobs do
      user_signs_up(params, password: password)
    end

    expect_to_see_account_confirmation_page

    confirm_account
  end

  def subscription_regular_sign_up
    stub_signing_key

    user_registers_from_subscription

    expect_to_see_account_confirmation_page

    confirm_account
  end

  def sso_sign_up(params = {}, name: 'Registering User')
    stub_saas_features(identity_verification: true)

    with_omniauth_full_host do
      user_signs_up_with_sso(params, name: name)

      expect_to_see_identity_verification_page

      verify_email
    end

    expect_verification_completed
  end

  def user_signs_up(params = {}, password: User.random_password)
    new_user = build(:user, name: 'Registering User', email: user_email, password: password)

    visit new_user_registration_path(params)

    fill_in_sign_up_form(new_user)
  end

  def user_signs_up_with_sso(params = {}, provider: 'google_oauth2', name: 'Registering User')
    stub_arkose_token_verification

    mock_auth_hash(provider, 'external_uid', user_email, name: name)
    stub_omniauth_setting(block_auto_created_users: false)
    allow(::AntiAbuse::IdentityVerification::Settings).to receive(:arkose_enabled?).and_return(true)

    if block_given?
      yield
    else
      visit new_user_registration_path(params)
    end

    wait_for_all_requests

    click_link_or_button Gitlab::Auth::OAuth::Provider.label_for(provider)
  end

  def user_signs_up_through_subscription_with_sso(provider: 'google_oauth2')
    user_signs_up_with_sso({}, provider: provider) do
      visit new_subscriptions_path(plan_id: premium_plan_id)
      # expect sign in here
    end
  end

  def user_signs_up_through_trial_with_sso(params = {}, provider: 'google_oauth2', name: 'Registering User')
    user_signs_up_with_sso({}, provider: provider, name: name) do
      visit new_trial_registration_path(params)

      expect_to_be_on_trial_user_registration
    end
  end

  def user_signs_up_through_signin_with_sso(params = {})
    user_signs_up_with_sso({}, provider: 'google_oauth2') do
      visit new_user_session_path(params)

      expect_to_be_on_user_sign_in
    end
  end

  def trial_registration_sign_up(params = {})
    visit new_trial_registration_path(params)

    expect_to_be_on_trial_user_registration

    user_signs_up_through_trial_registration

    expect_to_see_account_confirmation_page

    confirm_account
  end

  def sso_trial_registration_sign_up(params = {}, name: 'Registering User')
    stub_saas_features(identity_verification: true)

    with_omniauth_full_host do
      user_signs_up_through_trial_with_sso(params, name: name)

      expect_to_see_identity_verification_page

      verify_email
    end

    expect_verification_completed
  end

  def sso_subscription_sign_up
    stub_signing_key
    stub_saas_features(identity_verification: true)

    with_omniauth_full_host do
      user_signs_up_through_subscription_with_sso

      expect_to_see_identity_verification_page

      verify_email
    end

    expect_verification_completed
  end

  def sso_signup_through_signin
    stub_saas_features(identity_verification: true)

    with_omniauth_full_host do
      user_signs_up_through_signin_with_sso

      expect_to_see_identity_verification_page

      verify_email
    end

    expect_verification_completed
  end

  def user_signs_up_through_trial_registration
    new_user = build(:user, name: 'Registering User', email: user_email)

    perform_enqueued_jobs do
      fill_in_sign_up_form(new_user)
    end
  end

  def ensure_onboarding
    yield

    visit root_path

    yield
  end

  def ensure_onboarding_is_finished
    visit root_path
    expect(page).to have_current_path(root_path)
  end

  def user_registers_from_subscription
    new_user = build(:user, name: 'Registering User', email: user_email)

    visit new_subscriptions_path(plan_id: premium_plan_id)

    perform_enqueued_jobs do
      fill_in_sign_up_form(new_user)
    end
  end

  def glm_params
    {
      glm_source: 'some_source',
      glm_content: 'some_content'
    }
  end

  def expect_to_be_in_import_process
    expect(page).to have_content <<~MESSAGE.tr("\n", ' ')
      To import GitHub repositories, you must first authorize
      GitLab to access your GitHub repositories.
    MESSAGE
  end

  def expect_to_see_import_form
    stub_feature_flags(new_project_creation_form: false)
    expect_to_see_group_and_project_creation_form
    expect(page).to have_content('GitLab export')
  end

  def expect_to_be_on_trial_user_registration
    expect(page).to have_content('Enjoy 60 days of full access to our best plan')
  end

  def expect_to_be_on_user_sign_in
    expect(page).to have_content('By signing in you accept')
  end

  def expect_to_be_in_learn_gitlab
    expect(page).to have_content('Learn GitLab')

    page.within('[data-testid="invite-modal"]') do
      expect(page).to have_content('GitLab is better with colleagues!')
      expect(page).to have_content('Congratulations on creating your project')
    end
  end

  def expect_to_be_in_get_started
    within_testid('super-sidebar') do
      expect(page).to have_link('Get started')
    end

    within_testid('top-bar') do
      expect(page).to have_link('Get started')
    end

    within_testid('get-started-page') do
      expect(page).to have_content('Quick start')
    end
  end

  def expect_to_see_group_and_project_creation_form
    expect(page).to have_content('Create or import your first project')
    expect(page).to have_content('Projects help you organize your work')
    expect(page).to have_content('Your project will be created at:')
  end

  def expect_to_see_company_form
    expect(page).to have_content 'Tell us about your company'
  end

  def expect_to_apply_trial(glm: true)
    service_instance = instance_double(GitlabSubscriptions::Trials::ApplyTrialService)
    allow(GitlabSubscriptions::Trials::ApplyTrialService).to receive(:new).and_return(service_instance)

    expect(service_instance).to receive(:execute).and_return(ServiceResponse.success)

    expect_to_call_apply_trial(glm)
  end

  def expect_to_call_apply_trial(glm = nil)
    trial_user_information = {
      namespace_id: anything,
      gitlab_com_trial: true,
      sync_to_gl: true,
      namespace: {
        id: anything,
        name: 'Test Group',
        path: 'test-group',
        kind: 'group',
        trial_ends_on: nil
      }
    }

    trial_user_information.merge!(glm_params) if glm

    expect(GitlabSubscriptions::Trials::ApplyTrialWorker)
      .to receive(:perform_async).with(
        user.id,
        trial_user_information.deep_stringify_keys
      ).and_call_original
  end

  def expect_to_be_on_projects_dashboard
    expect(page).to have_content 'There are no projects available to be displayed here.'
  end

  def expect_to_be_on_projects_dashboard_with_zero_authorized_projects
    expect(page).to have_content 'Welcome to GitLab'
    expect(page).to have_content 'Ready to get started with GitLab? Follow these steps to get familiar with us:'

    page.within('[data-testid="joining-a-project-alert"') do
      expect(page).to have_content 'Looking for your team?'
    end
  end

  def super_sidebar_selector
    '[data-testid="super-sidebar"]'
  end

  def expect_to_see_group_overview_page
    page.within(super_sidebar_selector) do
      expect(page).to have_content('Test group')
    end

    page.within('.content-wrapper') do
      expect(page).to have_content('Welcome to GitLab, Registering!')
      expect(page).to have_content('Subgroups and projects')
    end
  end

  def welcome_form_selector
    '[data-testid="welcome-form"]'
  end

  def expect_to_see_subscription_welcome_form
    expect(page).to have_content('Welcome to GitLab, Registering!')

    page.within(welcome_form_selector) do
      expect(page).to have_content('Role')
      expect(page).to have_field('user_onboarding_status_role', valid: false)
      expect(page).to have_field('user_onboarding_status_setup_for_company_true', valid: false)
      expect(page).to have_content('I\'m signing up for GitLab because:')
      expect(page).to have_content('Who will be using this GitLab subscription?')
      expect(page).to have_content('What would you like to do?')
    end
  end

  def fills_in_group_and_project_creation_form
    # The groups_and_projects_controller (on `click_on 'Create project'`) is over
    # the query limit threshold, so we have to adjust it.
    # https://gitlab.com/gitlab-org/gitlab/-/issues/404805
    allow(Gitlab::QueryLimiting::Transaction).to receive(:threshold).and_return(170)

    fill_in 'group_name', with: 'Test Group'
    fill_in 'blank_project_name', with: 'Test Project'
  end

  def fills_in_group_and_project_creation_form_with_trial(glm: true)
    fills_in_group_and_project_creation_form

    service_instance = instance_double(GitlabSubscriptions::Trials::ApplyTrialService)
    allow(GitlabSubscriptions::Trials::ApplyTrialService).to receive(:new).and_return(service_instance)

    expect(service_instance).to receive(:execute).and_return(ServiceResponse.success)

    trial_user_information = {
      namespace_id: anything,
      gitlab_com_trial: true,
      sync_to_gl: true,
      namespace: {
        id: anything,
        name: 'Test Group',
        path: 'test-group',
        kind: 'group',
        trial_ends_on: nil
      }
    }

    trial_user_information.merge!(glm_params) if glm

    expect(GitlabSubscriptions::Trials::ApplyTrialWorker)
      .to receive(:perform_async).with(
        user.id,
        trial_user_information.deep_stringify_keys
      ).and_call_original
  end

  def fill_in_company_form(with_last_name: false, success: true)
    result = if success
               ServiceResponse.success
             else
               ServiceResponse.error(message: '_company_lead_fail_')
             end

    expect(GitlabSubscriptions::CreateCompanyLeadService).to receive(:new).with(
      user: user,
      params: company_params(user)
    ).and_return(instance_double(GitlabSubscriptions::CreateCompanyLeadService, execute: result))

    fill_in_company_user_last_name if with_last_name
    fill_company_form_fields
  end

  def fill_in_company_user_last_name
    fill_in 'last_name', with: 'User'
  end

  def fill_company_form_fields
    fill_in 'company_name', with: 'Test Company'
    select 'United States of America', from: 'country'
    select 'Florida', from: 'state'
    fill_in 'phone_number', with: '+1234567890'
  end

  def company_params(user)
    ActionController::Parameters.new(
      company_name: 'Test Company',
      first_name: user.first_name,
      last_name: 'User',
      phone_number: '+1234567890',
      country: 'US',
      state: 'FL',
      # these are the passed through params
      jobs_to_be_done_other: 'My reason'
    ).permit!
  end

  def premium_plan_id
    "premium-plan-id"
  end

  def premium_plan
    {
      id: premium_plan_id,
      name: "Premium Plan",
      free: false,
      code: "premium",
      price_per_year: 48.0,
      purchase_link: {
        action: "upgrade",
        href: "https://customers.gitlab.com/subscriptions/new?plan_id=#{premium_plan_id}"
      }
    }
  end

  def stub_subscription_plans
    plan_data = [premium_plan]
    allow_next_instance_of(GitlabSubscriptions::FetchSubscriptionPlansService) do |instance|
      allow(instance).to receive(:execute).and_return(plan_data)
    end
  end

  def customer_params
    company = user.onboarding_status_setup_for_company ? 'Test company' : nil

    ActionController::Parameters.new(
      country: 'US',
      address_1: '123 fake street',
      address_2: nil,
      city: 'Fake city',
      state: 'FL',
      zip_code: 'A1B 2C3',
      company: company
    ).permit!
  end

  def expect_to_see_subscription_group_selection_form
    expect(page).to have_content('Select a group for your Premium subscription')
    expect(page).to have_content('Your subscription will be applied to this group')
  end

  def expect_to_see_company_form_failure
    page.within('[data-testid="alert-danger"]') do
      expect(page).to have_content('_company_lead_fail_')
    end
  end

  def expect_to_send_iterable_request(invite: false)
    allow_next_instance_of(::Onboarding::CreateIterableTriggerService) do |instance|
      allow(instance).to receive(:execute).and_return(ServiceResponse.success)
    end

    product_interaction = if invite
                            'Invited User'
                          else
                            'Personal SaaS Registration'
                          end

    params = {
      provider: 'gitlab',
      work_email: user.email,
      uid: user.id,
      preferred_language: 'English',
      comment: 'My reason',
      role: 'software_developer',
      jtbd: 'other',
      product_interaction: product_interaction
    }

    expect(::Onboarding::CreateIterableTriggerWorker).to receive(:perform_async).with(
      hash_including(**params.stringify_keys)
    ).and_call_original
  end

  def expect_not_to_send_iterable_request
    expect(::Onboarding::CreateIterableTriggerWorker).not_to receive(:perform_async)
  end
end

SaasRegistrationHelpers.prepend_mod
