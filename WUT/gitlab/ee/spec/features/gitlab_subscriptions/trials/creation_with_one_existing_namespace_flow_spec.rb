# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Trial lead submission and creation with one eligible namespace', :saas_trial, :js, :use_clean_rails_memory_store_caching, feature_category: :plan_provisioning do
  let_it_be(:user, reload: true) { create(:user) } # rubocop:disable Gitlab/RSpec/AvoidSetup -- to skip registration and creating group
  let_it_be_with_reload(:group) { create(:group_with_plan, name: 'gitlab', owners: user) } # rubocop:disable Gitlab/RSpec/AvoidSetup -- to skip registration and creating group

  before_all do
    create(:gitlab_subscription_add_on, :duo_enterprise)
  end

  context 'when creating lead and applying trial is successful' do
    it 'fills out form, submits and lands on the duo page' do
      sign_in(user)

      stub_cdot_namespace_eligible_trials
      visit new_trial_path

      fill_in_company_information_single_step

      submit_single_namespace_trial_form

      expect_to_be_on_gitlab_duo_page
    end

    context 'when last name is blank' do
      it 'fills out form, including last name, submits and lands on the duo page' do
        user.update!(name: 'Bob')

        sign_in(user)

        stub_cdot_namespace_eligible_trials
        visit new_trial_path

        expect_to_be_on_trial_form_with_name_fields

        fill_in_company_information_single_step_with_last_name('Smith')

        submit_single_namespace_trial_form(last_name: 'Smith')

        expect_to_be_on_gitlab_duo_page
      end
    end

    context 'on a premium plan' do
      it 'fills out form, submits and lands on the group page' do
        group.gitlab_subscription.update!(hosted_plan_id: create(:premium_plan).id)

        sign_in(user)

        stub_cdot_namespace_eligible_trials
        visit new_trial_path

        fill_in_company_information_single_step

        submit_single_namespace_trial_form

        expect_to_be_on_gitlab_duo_page(path: group.name)
      end
    end

    context 'on a free plan and has previously had a legacy ultimate trial' do
      it 'fills out form, submits and lands on the group page' do
        group.gitlab_subscription.update!(
          trial: true,
          trial_starts_on: 1.month.ago,
          trial_ends_on: 10.days.ago
        )

        sign_in(user)

        stub_cdot_namespace_eligible_trials
        visit new_trial_path

        fill_in_company_information_single_step

        submit_single_namespace_trial_form

        expect_to_be_on_gitlab_duo_page(path: group.name)
      end
    end

    context 'on a premium plan and has previously had a legacy ultimate trial' do
      it 'fills out form, submits and lands on the group page' do
        group.gitlab_subscription.update!(
          hosted_plan_id: create(:premium_plan).id,
          trial: true,
          trial_starts_on: 1.month.ago,
          trial_ends_on: 10.days.ago
        )

        sign_in(user)

        stub_cdot_namespace_eligible_trials
        visit new_trial_path

        fill_in_company_information_single_step

        submit_single_namespace_trial_form

        expect_to_be_on_gitlab_duo_page(path: group.name)
      end
    end

    context 'when part of the discover security flow' do
      it 'fills out form, submits and lands on the group security dashboard page' do
        sign_in(user)

        stub_cdot_namespace_eligible_trials
        visit new_trial_path(glm_content: 'discover-group-security')

        fill_in_company_information_single_step

        submit_single_namespace_trial_form(glm: { glm_content: 'discover-group-security' })

        expect_to_be_on_group_security_dashboard
      end
    end
  end

  context 'when applying lead fails' do
    it 'fills out form, submits and sent back to information form with errors and is then resolved' do
      # setup
      sign_in(user)

      stub_cdot_namespace_eligible_trials
      visit new_trial_path

      fill_in_company_information_single_step

      # lead failure
      submit_single_namespace_trial_form(lead_result: lead_failure)

      expect_to_be_on_form_with_trial_submission_error

      # success
      resubmit_full_request

      expect_to_be_on_gitlab_duo_page
    end
  end

  context 'when applying trial fails' do
    it 'fills out form, submits and is sent to select namespace with errors and is then resolved' do
      # setup
      sign_in(user)

      stub_cdot_namespace_eligible_trials
      visit new_trial_path

      fill_in_company_information_single_step

      # trial failure
      submit_single_namespace_trial_form(trial_result: trial_failure)

      expect_to_be_on_form_with_trial_submission_error

      # success
      resubmit_trial_request

      expect_to_be_on_gitlab_duo_page
    end
  end

  def submit_single_namespace_trial_form(
    lead_result: ServiceResponse.success,
    trial_result: ServiceResponse.success,
    glm: {},
    extra_params: {},
    last_name: user.last_name
  )
    # lead
    expect_lead_submission(lead_result, last_name: last_name, glm: glm)

    # trial
    if lead_result.success? # rubocop:disable RSpec/AvoidConditionalStatements -- Not applicable in helper method
      stub_apply_trial(
        namespace_id: group.id,
        result: trial_result,
        extra_params: extra_params.merge(existing_group_attrs).merge(glm)
      )
      stub_duo_landing_page_data
    end

    click_button 'Activate my trial'

    wait_for_requests
  end

  def expect_to_be_on_trial_form_with_name_fields
    within_testid('trial-form') do
      expect(find_by_testid('first-name-field').value).to have_content(user.first_name)
      expect(find_by_testid('last-name-field').value).to have_content(user.last_name)
    end
  end
end
