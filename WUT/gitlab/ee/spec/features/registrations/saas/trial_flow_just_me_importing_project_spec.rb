# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Trial flow for user picking just me and importing a project', :js, :saas_registration, :with_current_organization, feature_category: :onboarding do
  where(:case_name, :sign_up_method) do
    [
      ['with regular trial sign up', -> { trial_registration_sign_up }],
      ['with sso trial sign up', -> { sso_trial_registration_sign_up }]
    ]
  end

  with_them do
    it 'registers the user and starts to import a project' do
      sign_up_method.call

      expect_to_see_welcome_form

      fills_in_welcome_form
      click_on 'Continue'

      expect_to_see_company_form

      fill_in_company_form
      click_on 'Continue'

      expect_to_see_group_and_project_creation_form

      click_on 'Import'

      expect_to_see_import_form

      fills_in_import_form
      expect_to_call_apply_trial
      click_on 'GitHub'

      expect_to_be_in_import_process
    end
  end

  def fills_in_welcome_form
    select 'Software Developer', from: 'user_onboarding_status_role'
    select 'A different reason', from: 'user_onboarding_status_registration_objective'
    fill_in 'Why are you signing up? (optional)', with: 'My reason'

    choose 'Just me'
  end

  def expect_to_see_welcome_form
    expect(page).to have_content('Welcome to GitLab, Registering!')

    page.within(welcome_form_selector) do
      expect(page).to have_content('Role')
      expect(page).to have_field('user_onboarding_status_role', valid: false)
      expect(page).to have_field('user_onboarding_status_setup_for_company_true', valid: false)
      expect(page).not_to have_content('What would you like to do?')
      expect(page).to have_content('I\'m signing up for GitLab because:')
      expect(page).to have_content('Who will be using this GitLab trial?')
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

  def fills_in_import_form
    fill_in 'import_group_name', with: 'Test Group'
  end
end
