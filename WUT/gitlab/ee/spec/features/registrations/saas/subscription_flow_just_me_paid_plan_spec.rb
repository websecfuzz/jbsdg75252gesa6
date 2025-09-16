# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Subscription flow for user picking just me for paid plan', :js, :saas_registration, :with_current_organization, feature_category: :onboarding do
  where(:case_name, :sign_up_method) do
    [
      ['with regular sign up', -> { subscription_regular_sign_up }],
      ['with sso sign up', -> { sso_subscription_sign_up }]
    ]
  end

  with_them do
    it 'registers the user and redirects to subscription group selection page' do
      stub_subscription_plans
      sign_up_method.call

      expect_to_see_subscription_welcome_form
      expect_not_to_send_iterable_request

      fills_in_welcome_form
      click_on 'Continue'

      expect_to_see_subscription_group_selection_form
    end
  end

  def fills_in_welcome_form
    select 'Software Developer', from: 'user_onboarding_status_role'
    select 'A different reason', from: 'user_onboarding_status_registration_objective'
    fill_in 'Why are you signing up? (optional)', with: 'My reason'

    choose 'Just me'
    choose 'Create a new project' # does not matter here if choose 'Join a project'
  end
end
