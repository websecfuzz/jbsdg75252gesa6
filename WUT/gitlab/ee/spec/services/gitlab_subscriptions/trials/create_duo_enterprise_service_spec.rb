# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::CreateDuoEnterpriseService, feature_category: :plan_provisioning do
  include TrialHelpers

  let_it_be(:user, reload: true) { create(:user, preferred_language: 'en') }
  let(:step) { described_class::LEAD }

  describe '#execute', :saas do
    let(:trial_params) { {} }
    let(:extra_lead_params) { {} }
    let(:trial_user_params) do
      { trial_user: lead_params(user, extra_lead_params).merge({ add_on_name: 'duo_enterprise' }) }
    end

    let(:lead_service_class) { GitlabSubscriptions::Trials::CreateAddOnLeadService }
    let(:apply_trial_service_class) { GitlabSubscriptions::Trials::ApplyDuoEnterpriseService }
    let(:add_on_purchase) { build(:gitlab_subscription_add_on_purchase) }

    before_all do
      create(:gitlab_subscription_add_on, :duo_enterprise)
    end

    subject(:execute) do
      described_class.new(
        step: step, lead_params: lead_params(user, extra_lead_params), trial_params: trial_params, user: user
      ).execute
    end

    it_behaves_like 'performing the lead step', :ultimate_plan
    it_behaves_like 'performing the trial step', :ultimate_plan
    it_behaves_like 'unknown step for trials'
    it_behaves_like 'no step for trials'

    it_behaves_like 'for tracking the lead step', :ultimate_plan, 'duo_enterprise_'
    it_behaves_like 'for tracking the trial step', :ultimate_plan, 'duo_enterprise_'

    it_behaves_like 'creating add-on when namespace_id is provided', :ultimate_plan, :premium_plan
  end

  def lead_params(user, extra_lead_params)
    {
      company_name: 'GitLab',
      first_name: user.first_name,
      last_name: user.last_name,
      phone_number: '+1 23 456-78-90',
      country: 'US',
      work_email: user.email,
      uid: user.id,
      setup_for_company: user.onboarding_status_setup_for_company,
      skip_email_confirmation: true,
      gitlab_com_trial: true,
      provider: 'gitlab',
      product_interaction: 'duo_enterprise_trial',
      preferred_language: 'English',
      opt_in: user.onboarding_status_email_opt_in
    }.merge(extra_lead_params)
  end
end
