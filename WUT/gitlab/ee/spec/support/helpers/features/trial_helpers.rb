# frozen_string_literal: true

require 'support/helpers/listbox_helpers'
require_relative '../subscription_portal_helpers'

module Features
  module TrialHelpers
    include ListboxHelpers
    include SubscriptionPortalHelpers

    def expect_to_be_on_namespace_selection_with_errors
      expect_to_be_on_namespace_selection
      expect(page).to have_content('could not be created because our system did not respond successfully')
      expect(page).to have_content('Please reach out to GitLab Support for assistance')
      expect(page).to have_link('GitLab Support', href: 'https://support.gitlab.com')
    end

    def expect_to_be_on_duo_enterprise_namespace_selection_with_errors
      expect_to_be_on_duo_enterprise_namespace_selection
      expect(page).to have_content('could not be created because our system did not respond successfully')
      expect(page).to have_content('Please reach out to GitLab Support for assistance')
      expect(page).to have_link('GitLab Support', href: 'https://support.gitlab.com')
    end

    def expect_to_be_on_duo_enterprise_namespace_selection
      expect(page).to have_content('This trial is for')
    end

    def expect_to_be_on_duo_pro_namespace_selection_with_errors
      expect_to_be_on_duo_pro_namespace_selection
      expect(page).to have_content('could not be created because our system did not respond successfully')
      expect(page).to have_content('Please reach out to GitLab Support for assistance')
      expect(page).to have_link('GitLab Support', href: 'https://support.gitlab.com')
    end

    def expect_to_be_on_duo_pro_namespace_selection
      expect(page).to have_content('Apply your GitLab Duo Pro trial to an existing group')
    end

    def expect_to_be_on_namespace_selection
      expect(page).to have_content('Apply your trial to a new or existing group')
      expect(page).to have_content('This trial is for')
    end

    def expect_to_be_on_lead_form_with_name_fields
      within_testid('lead-form') do
        expect(find_by_testid('first-name-field').value).to have_content(user.first_name)
        expect(find_by_testid('last-name-field').value).to have_content(user.last_name)
      end
    end

    def expect_to_have_namespace_creation_errors(group_name: '_invalid group name_', error_message: 'Group URL can')
      within('[data-testid="trial-form"]') do
        expect(page).not_to have_content('This trial is for')
        expect(page.find_field('new_group_name').value).to eq(group_name)
        expect(page).to have_content(error_message)
      end
    end

    def expect_to_be_on_lead_form_with_errors
      expect(page).to have_content('could not be created because our system did not respond successfully')
      expect(page).to have_content('_lead_fail_')

      # This is needed to ensure the countries and regions selector has time to populate
      # This only happens on the duo trial and not the regular trial. Probably due to the added time for full page
      # to load with background on duo trial. However, this wait should be present anyway to avoid possible flakiness.
      wait_for_all_requests
    end

    def expect_to_be_on_group_security_dashboard(group_for_path: group)
      expect(page).to have_current_path(group_security_dashboard_path(group_for_path))
      within_testid('super-sidebar') do
        expect(page).to have_link(group_for_path.name)
      end
    end

    def expect_to_be_on_gitlab_duo_page(path: 'gitlab', name: 'gitlab')
      expect(page).to have_current_path("/groups/#{path}/-/settings/gitlab_duo")
      within_testid('super-sidebar') do
        expect(page).to have_link(name)
      end
    end

    def fill_in_trial_selection_form(from: 'Select a group', group_select: true)
      select_from_listbox group.name, from: from if group_select
    end

    def fill_in_duo_enterprise_trial_selection_form(from: 'Select a group', group_select: true)
      select_from_listbox group.name, from: from if group_select
    end

    def fill_in_trial_form_for_new_group(name: 'gitlab')
      fill_in 'new_group_name', with: name
    end

    def form_data
      {
        phone_number: '+1 23 456-78-90',
        company_name: 'GitLab',
        country: { id: 'US', name: 'United States of America' },
        state: { id: 'CA', name: 'California' }
      }
    end

    def fill_in_company_information
      fill_in 'company_name', with: form_data[:company_name]
      fill_in 'phone_number', with: form_data[:phone_number]
      select form_data.dig(:country, :name), from: 'country'
      select form_data.dig(:state, :name), from: 'state'
    end

    def fill_in_company_information_single_step
      fill_in 'company_name', with: form_data[:company_name]
      fill_in 'phone_number', with: form_data[:phone_number]
      select_from_listbox form_data.dig(:country, :name), from: 'Select a country or region'
      select_from_listbox form_data.dig(:state, :name), from: 'Select state or province'
    end

    def fill_in_company_information_with_last_name(last_name)
      fill_in 'last_name', with: last_name
      fill_in_company_information
    end

    def fill_in_company_information_single_step_with_last_name(last_name)
      fill_in 'last_name', with: last_name
      fill_in_company_information_single_step
    end

    def resubmit_full_request(
      lead_result: ServiceResponse.success,
      trial_result: ServiceResponse.success,
      glm: {}
    )
      # lead
      expect_lead_submission(lead_result, last_name: user.last_name, glm: glm)

      # trial
      if lead_result.success?
        stub_apply_trial(namespace_id: group.id, result: trial_result, extra_params: existing_group_attrs)
        stub_duo_landing_page_data
      end

      click_button 'Resubmit request'

      wait_for_requests
    end

    def resubmit_trial_request(result: ServiceResponse.success)
      stub_apply_trial(namespace_id: group.id, result: result, extra_params: existing_group_attrs)
      stub_duo_landing_page_data

      click_button 'Resubmit request'

      wait_for_requests
    end

    def expect_to_be_on_form_with_trial_submission_error
      expect(page).to have_content('your trial could not be created')
      expect(page).to have_button('Resubmit request')
    end

    def expect_lead_submission(lead_result, glm:, last_name: user.last_name)
      trial_user_params = {
        company_name: form_data[:company_name],
        first_name: user.first_name,
        last_name: last_name,
        phone_number: form_data[:phone_number],
        country: form_data.dig(:country, :id),
        work_email: user.email,
        uid: user.id,
        setup_for_company: user.onboarding_status_setup_for_company,
        skip_email_confirmation: true,
        gitlab_com_trial: true,
        provider: 'gitlab',
        state: form_data.dig(:state, :id)
      }.merge(glm)

      expect_next_instance_of(GitlabSubscriptions::CreateLeadService) do |service|
        expect(service).to receive(:execute).with({ trial_user: trial_user_params }).and_return(lead_result)
      end
    end

    def submit_new_group_trial_form(
      lead_result: ServiceResponse.success,
      trial_result: ServiceResponse.success,
      glm: {},
      extra_params: {}
    )
      # lead
      expect_lead_submission(lead_result, glm: glm)

      # trial
      if lead_result.success?
        stub_apply_trial(result: trial_result, extra_params: extra_params.merge(glm))
        stub_duo_landing_page_data
      end

      click_button 'Activate my trial'

      wait_for_requests
    end

    def submit_company_information_form(
      button_text: 'Continue',
      lead_result: ServiceResponse.success,
      trial_result: ServiceResponse.success,
      with_trial: false,
      last_name: user.last_name,
      extra_params: {}
    )
      # lead
      trial_user_params = {
        company_name: form_data[:company_name],
        first_name: user.first_name,
        last_name: last_name,
        phone_number: form_data[:phone_number],
        country: form_data.dig(:country, :id),
        work_email: user.email,
        uid: user.id,
        setup_for_company: user.onboarding_status_setup_for_company,
        skip_email_confirmation: true,
        gitlab_com_trial: true,
        provider: 'gitlab',
        state: form_data.dig(:state, :id)
      }.merge(extra_params)

      expect_next_instance_of(GitlabSubscriptions::CreateLeadService) do |service|
        expect(service).to receive(:execute).with({ trial_user: trial_user_params }).and_return(lead_result)
      end

      # trial
      if with_trial
        stub_apply_trial(
          namespace_id: group.id, result: trial_result, extra_params: extra_params.merge(existing_group_attrs)
        )
        stub_duo_landing_page_data
      end

      click_button button_text

      wait_for_requests
    end

    def submit_trial_selection_form(result: ServiceResponse.success, extra_params: {})
      stub_apply_trial(
        namespace_id: group.id,
        result: result,
        extra_params: extra_params.merge(existing_group_attrs)
      )
      stub_duo_landing_page_data

      click_button 'Activate my trial'
    end

    def submit_new_group_trial_selection_form(result: ServiceResponse.success, extra_params: {})
      stub_apply_trial(result: result, extra_params: extra_params)
      stub_duo_landing_page_data

      click_button 'Activate my trial'
    end

    def update_with_applied_trials
      group = Group.last
      plan = create(:ultimate_trial_plan)
      group.gitlab_subscription.update!(
        hosted_plan: plan, trial: true, trial_starts_on: Time.current, trial_ends_on: Time.current + 60.days
      )

      update_with_duo_enterprise_trial
    end

    def stub_duo_landing_page_data
      stub_licensed_features(code_suggestions: true)
      stub_signing_key
    end

    def existing_group_attrs
      { namespace: group.slice(:id, :name, :path, :kind, :trial_ends_on).merge(plan: group.actual_plan.name) }
    end

    def new_group_attrs(path: 'gitlab', name: 'gitlab')
      {
        namespace: {
          id: anything,
          path: path,
          name: name,
          kind: 'group',
          trial_ends_on: nil,
          plan: 'free'
        }
      }
    end

    def stub_apply_trial(namespace_id: anything, result: ServiceResponse.success, extra_params: {})
      trial_user_params = {
        namespace_id: namespace_id,
        gitlab_com_trial: true,
        sync_to_gl: true
      }.merge(extra_params)

      service_params = {
        trial_user_information: trial_user_params,
        uid: user.id
      }

      expect_next_instance_of(GitlabSubscriptions::Trials::ApplyTrialService, service_params) do |instance|
        expect(instance).to receive(:execute) do
          if result.success?
            add_on_purchase = update_with_applied_trials
            result = ServiceResponse.success(payload: { add_on_purchase: add_on_purchase })
          end

          result
        end
      end
    end

    def submit_duo_pro_trial_company_form(
      lead_result: ServiceResponse.success,
      trial_result: ServiceResponse.success,
      with_trial: false,
      last_name: user.last_name,
      button_text: 'Continue'
    )
      # lead
      trial_user_params = {
        company_name: form_data[:company_name],
        first_name: user.first_name,
        last_name: last_name,
        phone_number: form_data[:phone_number],
        country: form_data.dig(:country, :id),
        work_email: user.email,
        uid: user.id,
        setup_for_company: user.onboarding_status_setup_for_company,
        skip_email_confirmation: true,
        gitlab_com_trial: true,
        provider: 'gitlab',
        state: form_data.dig(:state, :id),
        product_interaction: 'duo_pro_trial',
        preferred_language: ::Gitlab::I18n.trimmed_language_name(user.preferred_language),
        opt_in: user.onboarding_status_email_opt_in,
        add_on_name: 'code_suggestions'
      }

      expect_next_instance_of(GitlabSubscriptions::Trials::CreateAddOnLeadService) do |service|
        expect(service).to receive(:execute).with({ trial_user: trial_user_params }).and_return(lead_result)
      end

      # trial
      if with_trial
        stub_apply_duo_pro_trial(result: trial_result)
        stub_duo_landing_page_data
      end

      click_button button_text

      wait_for_requests
    end

    def stub_apply_duo_pro_trial(result: ServiceResponse.success)
      trial_user_params = {
        namespace_id: group.id,
        gitlab_com_trial: true,
        sync_to_gl: true
      }.merge(existing_group_attrs)

      service_params = {
        trial_user_information: trial_user_params,
        uid: user.id
      }

      expect_next_instance_of(GitlabSubscriptions::Trials::ApplyDuoProService, service_params) do |instance|
        expect(instance).to receive(:execute) do
          if result.success?
            add_on_purchase = update_with_duo_pro_trial
            result = ServiceResponse.success(payload: { add_on_purchase: add_on_purchase })
          end

          result
        end
      end
    end

    def update_with_duo_pro_trial
      group = Group.last
      add_on = GitlabSubscriptions::AddOn.find_by_name('code_suggestions')
      add_on_purchase = create(:gitlab_subscription_add_on_purchase, :trial, add_on: add_on, namespace: group)

      # stub needed for landing on the duo page
      stub_subscription_permissions_data(group.id)

      add_on_purchase
    end

    def stub_apply_duo_enterprise_trial(result: ServiceResponse.success, extra_params: {})
      trial_user_params = {
        namespace_id: group.id,
        gitlab_com_trial: true,
        sync_to_gl: true
      }.merge(existing_group_attrs).merge(extra_params)

      service_params = {
        trial_user_information: trial_user_params,
        uid: user.id
      }

      expect_next_instance_of(GitlabSubscriptions::Trials::ApplyDuoEnterpriseService, service_params) do |instance|
        expect(instance).to receive(:execute) do
          if result.success?
            add_on_purchase = update_with_duo_enterprise_trial
            result = ServiceResponse.success(payload: { add_on_purchase: add_on_purchase })
          end

          result
        end
      end
    end

    def update_with_duo_enterprise_trial
      group = Group.last
      add_on = GitlabSubscriptions::AddOn.find_by_name('duo_enterprise')
      add_on_purchase = create(:gitlab_subscription_add_on_purchase, :trial, add_on: add_on, namespace: group)

      # stub needed for landing on the duo page
      stub_subscription_permissions_data(group.id)

      add_on_purchase
    end

    def trial_failure
      ServiceResponse
        .error(message: '_trial_fail_', reason: GitlabSubscriptions::Trials::BaseApplyTrialService::GENERIC_TRIAL_ERROR)
    end

    def lead_failure
      ServiceResponse.error(message: '_lead_fail_', reason: :lead_failed)
    end

    def submit_duo_enterprise_trial_company_form(
      lead_result: ServiceResponse.success,
      trial_result: ServiceResponse.success,
      with_trial: false,
      last_name: user.last_name,
      button_text: 'Continue'
    )
      # lead
      trial_user_params = {
        company_name: form_data[:company_name],
        first_name: user.first_name,
        last_name: last_name,
        phone_number: form_data[:phone_number],
        country: form_data.dig(:country, :id),
        work_email: user.email,
        uid: user.id,
        setup_for_company: user.onboarding_status_setup_for_company,
        skip_email_confirmation: true,
        gitlab_com_trial: true,
        provider: 'gitlab',
        state: form_data.dig(:state, :id),
        product_interaction: 'duo_enterprise_trial',
        preferred_language: ::Gitlab::I18n.trimmed_language_name(user.preferred_language),
        opt_in: user.onboarding_status_email_opt_in,
        add_on_name: 'duo_enterprise'
      }

      expect_next_instance_of(GitlabSubscriptions::Trials::CreateAddOnLeadService) do |service|
        expect(service).to receive(:execute).with({ trial_user: trial_user_params }).and_return(lead_result)
      end

      # trial
      if with_trial
        stub_apply_duo_enterprise_trial(result: trial_result)
        stub_duo_landing_page_data
      end

      click_button button_text

      wait_for_requests
    end

    def submit_duo_pro_trial_selection_form(result: ServiceResponse.success)
      stub_apply_duo_pro_trial(result: result)
      stub_duo_landing_page_data

      click_button 'Activate my trial'
    end

    def submit_duo_enterprise_trial_selection_form(result: ServiceResponse.success)
      stub_apply_duo_enterprise_trial(result: result)
      stub_duo_landing_page_data

      click_button 'Activate my trial'
    end

    def stub_cdot_namespace_eligible_trials
      allow(Gitlab::SubscriptionPortal::Client).to receive(:namespace_eligible_trials) do |params|
        namespaces_response = params[:namespace_ids].to_h { |id| [id.to_s, GitlabSubscriptions::Trials::TRIAL_TYPES] }

        { success: true, data: { namespaces: namespaces_response } }
      end
    end
  end
end
