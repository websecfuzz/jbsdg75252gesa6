# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Single sign on for signing up through sign in flow for user picking company and creating a project', :js, :saas_registration, :with_current_organization, feature_category: :onboarding do
  context 'when opting into a trial' do
    it 'registers the user and creates a group and project reaching onboarding', :sidekiq_inline do
      sso_signup_through_signin

      ensure_onboarding { expect_to_see_welcome_form }

      fills_in_welcome_form
      click_on 'Continue'

      ensure_onboarding { expect_to_see_company_form }

      fill_in_company_form
      click_on s_('Trial|Continue with trial')

      ensure_onboarding { expect_to_see_group_and_project_creation_form }

      fills_in_group_and_project_creation_form
      expect_to_apply_trial(glm: false)
      click_on 'Create project'

      expect_to_be_in_get_started
    end
  end

  def fills_in_welcome_form
    select 'Software Developer', from: 'user_onboarding_status_role'
    select 'A different reason', from: 'user_onboarding_status_registration_objective'
    fill_in 'Why are you signing up? (optional)', with: 'My reason'

    choose 'My company or team'
    choose 'Create a new project'
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
    end
  end
end
