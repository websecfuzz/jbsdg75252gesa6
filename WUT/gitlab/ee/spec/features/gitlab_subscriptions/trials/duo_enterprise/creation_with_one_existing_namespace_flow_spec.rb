# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Duo Enterprise trial lead submission and creation with one eligible namespace', :saas_trial, :js, feature_category: :acquisition do
  # rubocop:disable Gitlab/RSpec/AvoidSetup -- to skip registration and creating group
  let_it_be(:user, reload: true) { create(:user) }
  let_it_be(:group) { create(:group_with_plan, plan: :ultimate_plan, name: 'gitlab', owners: user) }

  before_all do
    create(:gitlab_subscription_add_on, :duo_enterprise)
  end
  # rubocop:enable Gitlab/RSpec/AvoidSetup

  context 'when creating lead and applying trial is successful' do
    it 'fills out form, submits and lands on the group duo page' do
      sign_in(user)

      visit new_trials_duo_enterprise_path

      fill_in_company_information

      submit_single_namespace_duo_enterprise_trial_company_form(with_trial: true)

      expect_to_be_on_gitlab_duo_page
    end

    context 'when last name is blank' do
      it 'fills out form, including last name, submits and lands on the duo page' do
        user.update!(name: 'Bob')

        sign_in(user)

        visit new_trials_duo_enterprise_path

        expect_to_be_on_lead_form_with_name_fields

        fill_in_company_information_with_last_name('Smith')

        submit_single_namespace_duo_enterprise_trial_company_form(with_trial: true, last_name: 'Smith')

        expect_to_be_on_gitlab_duo_page
      end
    end
  end

  context 'when applying lead fails' do
    it 'fills out form, submits and sent back to information form with errors and is then resolved' do
      # setup
      sign_in(user)

      visit new_trials_duo_enterprise_path

      fill_in_company_information

      # lead failure
      submit_single_namespace_duo_enterprise_trial_company_form(lead_result: lead_failure)

      expect_to_be_on_lead_form_with_errors

      # success
      submit_single_namespace_duo_enterprise_trial_company_form(with_trial: true)

      expect_to_be_on_gitlab_duo_page
    end
  end

  context 'when applying trial fails' do
    it 'fills out form, submits and is sent back to information form with errors and is then resolved' do
      # setup
      sign_in(user)

      visit new_trials_duo_enterprise_path

      fill_in_company_information

      # trial failure
      submit_single_namespace_duo_enterprise_trial_company_form(with_trial: true, trial_result: trial_failure)

      expect_to_be_on_duo_enterprise_namespace_selection_with_errors

      wait_for_all_requests

      # success
      fill_in_duo_enterprise_trial_selection_form(group_select: false)

      submit_duo_enterprise_trial_selection_form

      expect_to_be_on_gitlab_duo_page
    end
  end

  def submit_single_namespace_duo_enterprise_trial_company_form(**kwargs)
    submit_duo_enterprise_trial_company_form(**kwargs, button_text: 'Activate my trial')
  end
end
