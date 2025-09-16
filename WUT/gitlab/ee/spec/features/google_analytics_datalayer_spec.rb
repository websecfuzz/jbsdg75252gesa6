# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'GitLab.com Google Analytics DataLayer', :saas, :js, feature_category: :application_instrumentation do
  include JavascriptFormHelper

  let(:google_tag_manager_id) { 'GTM-WWKMTWS' }
  let(:new_user) { build(:user) }
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }

  before do
    stub_application_setting(require_admin_approval_after_user_signup: false)
    stub_config(extra: { google_tag_manager_id: google_tag_manager_id, google_tag_manager_nonce_id: google_tag_manager_id })
  end

  context 'on account sign up pages' do
    context 'when creating a new trial registration' do
      it 'tracks form submissions in the dataLayer' do
        visit new_trial_registration_path

        prevent_submit_for('#new_new_user')

        fill_in_sign_up_form(new_user)

        data_layer = execute_script('return window.dataLayer')
        last_event_in_data_layer = data_layer[-1]

        expect(last_event_in_data_layer["event"]).to eq("accountSubmit")
        expect(last_event_in_data_layer["accountType"]).to eq("freeThirtyDayTrial")
        expect(last_event_in_data_layer["accountMethod"]).to eq("form")
      end
    end

    context 'when creating a new user' do
      it 'track form submissions in the dataLayer' do
        visit new_user_registration_path

        prevent_submit_for('#new_new_user')

        fill_in_sign_up_form(new_user)

        data_layer = execute_script('return window.dataLayer')
        last_event_in_data_layer = data_layer[-1]

        expect(last_event_in_data_layer["event"]).to eq("accountSubmit")
        expect(last_event_in_data_layer["accountType"]).to eq("standardSignUp")
        expect(last_event_in_data_layer["accountMethod"]).to eq("form")
      end
    end
  end

  context 'on duo pro trial group select page' do
    include ListboxHelpers

    before do
      create(:gitlab_subscription_add_on_purchase, :duo_pro)
    end

    it 'tracks create group events' do
      group = create(:group_with_plan, plan: :premium_plan, owners: user)

      sign_in user
      visit new_trials_duo_pro_path(step: GitlabSubscriptions::Trials::CreateDuoProService::TRIAL)

      prevent_submit_for('.js-saas-duo-pro-trial-group')

      select_from_listbox group.name, from: 'Select a group'
      click_button 'Activate my trial'

      data_layer = execute_script('return window.dataLayer')
      last_event_in_data_layer = data_layer[-1]

      expect(last_event_in_data_layer['event']).to eq('saasDuoProTrialGroup')
    end
  end

  context 'on duo enterprise trial group select page' do
    include ListboxHelpers

    before do
      create(:gitlab_subscription_add_on_purchase, :duo_enterprise)
    end

    it 'tracks create group events' do
      group = create(:group_with_plan, plan: :ultimate_plan, owners: user)

      sign_in user
      visit new_trials_duo_enterprise_path(step: GitlabSubscriptions::Trials::CreateDuoEnterpriseService::TRIAL)

      prevent_submit_for('.js-saas-duo-enterprise-trial-group')

      select_from_listbox group.name, from: 'Select a group'
      click_button 'Activate my trial'

      data_layer = execute_script('return window.dataLayer')
      last_event_in_data_layer = data_layer[-1]

      expect(last_event_in_data_layer['event']).to eq('saasDuoEnterpriseTrialGroup')
    end
  end
end
