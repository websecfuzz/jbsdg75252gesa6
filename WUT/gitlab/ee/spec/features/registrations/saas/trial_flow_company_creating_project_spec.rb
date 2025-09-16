# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Trial flow for user picking company and creating a project', :js, :saas_registration, :with_current_organization, feature_category: :onboarding do
  where(:case_name, :sign_up_method, :tracking_events_key) do
    [
      ['with regular trial sign up', ->(params) { trial_registration_sign_up(params) }, :trial_regular_signup],
      ['with sso trial sign up', ->(params) { sso_trial_registration_sign_up(params) }, :trial_sso_signup]
    ]
  end

  with_them do
    it 'registers the user and creates a group and project reaching onboarding', :snowplow_micro, :sidekiq_inline do
      sign_up_method.call(glm_params)

      ensure_onboarding { expect_to_see_welcome_form }

      fills_in_welcome_form
      click_on 'Continue'

      ensure_onboarding { expect_to_see_company_form }

      # failure
      fill_in_company_form(success: false)
      click_on 'Continue'

      expect_to_see_company_form_failure

      # success
      resubmit_company_form
      click_on 'Continue'

      ensure_onboarding { expect_to_see_group_and_project_creation_form }

      fills_in_group_and_project_creation_form_with_trial
      click_on 'Create project'

      expect_to_be_in_get_started
      expect(tracking_events_key).to have_all_expected_events
    end
  end

  context 'when last name is missing for SSO and has to be filled in' do
    it 'registers the user, creates a group and project reaching onboarding', :sidekiq_inline do
      sso_trial_registration_sign_up(name: 'Registering')

      ensure_onboarding { expect_to_see_welcome_form }

      fills_in_welcome_form
      click_on 'Continue'

      ensure_onboarding { expect_to_see_company_form }

      # failure
      fill_company_form_fields
      click_on 'Continue'

      expect(page).to have_native_text_validation_message('last_name')

      # success
      fill_in_company_form(with_last_name: true)
      click_on 'Continue'

      ensure_onboarding { expect_to_see_group_and_project_creation_form }

      fills_in_group_and_project_creation_form_with_trial(glm: false)
      click_on 'Create project'

      expect_to_be_in_get_started
    end
  end

  def resubmit_company_form
    expect(GitlabSubscriptions::CreateCompanyLeadService).to receive(:new).with(
      user: user,
      params: company_params(user)
    ).and_return(instance_double(GitlabSubscriptions::CreateCompanyLeadService, execute: ServiceResponse.success))
  end

  def fills_in_welcome_form
    select 'Software Developer', from: 'user_onboarding_status_role'
    select 'A different reason', from: 'user_onboarding_status_registration_objective'
    fill_in 'Why are you signing up? (optional)', with: 'My reason'

    choose 'My company or team'
  end

  def expect_to_see_welcome_form
    expect(page).to have_content('Welcome to GitLab, Registering!')

    page.within(welcome_form_selector) do
      expect(page).to have_content('Role')
      expect(page).to have_field('user_onboarding_status_role', valid: false)
      expect(page).to have_field('user_onboarding_status_setup_for_company_true', valid: false)
      expect(page).to have_content('I\'m signing up for GitLab because:')
      expect(page).not_to have_content('What would you like to do?')
      expect(page).to have_content('Who will be using this GitLab trial?')
      expect(page)
        .not_to have_content(_('Enables a free Ultimate + GitLab Duo Enterprise trial when you create a new project.'))
    end
  end

  def expect_to_see_group_and_project_creation_form
    expect(page).to have_content('Create or import your first project')
    expect(page).to have_content('Projects help you organize your work')
    expect(page).to have_content('Your project will be created at:')
  end
end
