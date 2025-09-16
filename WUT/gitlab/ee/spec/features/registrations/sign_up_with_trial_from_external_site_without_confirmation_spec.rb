# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Sign up with trial from external site without confirmation', :saas, :js, :with_current_organization,
  feature_category: :onboarding do
  include SaasRegistrationHelpers

  let_it_be(:glm_params) do
    { glm_source: 'some_source', glm_content: 'some_content' }
  end

  before do
    stub_application_setting(require_admin_approval_after_user_signup: false)
    stub_application_setting(import_sources: %w[github gitlab_project])

    # The groups_and_projects_controller (on `click_on 'Create project'`) is over
    # the query limit threshold, so we have to adjust it.
    # https://gitlab.com/gitlab-org/gitlab/-/issues/340302
    allow(Gitlab::QueryLimiting::Transaction).to receive(:threshold).and_return(163)

    subscription_portal_url = ::Gitlab::Routing.url_helpers.subscription_portal_url

    stub_request(:post, "#{subscription_portal_url}/trials")
  end

  it 'passes glm parameters until user is onboarded' do
    user = build_stubbed(:user)
    glm_params = { glm_source: 'some_source', glm_content: 'some_content' }

    visit new_user_registration_path(glm_params)

    fill_in_sign_up_form(user)

    select 'Software Developer', from: 'user_onboarding_status_role'
    choose 'My company or team'
    choose 'Create a new project'
    click_button 'Continue'

    expect(Gitlab::SubscriptionPortal::Client)
      .to receive(:generate_trial)
      .with(hash_including(glm_params))
      .and_call_original

    fill_in 'company_name', with: 'Company name'
    select 'Australia', from: 'country'
    click_on s_('Trial|Continue with trial')

    fill_in 'group_name', with: 'Group name'
    fill_in 'blank_project_name', with: 'Project name'
    click_button 'Create project'

    expect_to_be_in_get_started
  end
end
