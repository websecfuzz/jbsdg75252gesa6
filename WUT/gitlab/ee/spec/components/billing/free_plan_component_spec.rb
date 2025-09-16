# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Billing::FreePlanComponent, :aggregate_failures, type: :component, feature_category: :subscription_management do
  include SubscriptionPortalHelpers

  let(:namespace) { build(:group) }
  let(:plans_data) { billing_plans_data.map { |plan| Hashie::Mash.new(plan) } }
  let(:current_plan_code) { 'free' }
  let(:current_plan) { Hashie::Mash.new(code: current_plan_code) }

  subject do
    render_inline(described_class.new(plans_data: plans_data, namespace: namespace, current_plan: current_plan)) && page
  end

  it 'has plan specific content' do
    is_expected.to have_content(s_('BillingPlans|Use GitLab for personal projects'))
    is_expected.to have_content(s_('BillingPlans|No credit card required'))
    is_expected.to have_content(s_('BillingPlans|Free forever features:'))
    is_expected.to have_content(s_('BillingPlans|400 CI/CD minutes per month'))
  end

  it 'has header for the current plan' do
    is_expected.to have_content(s_('BillingPlans|Your current plan'))
    is_expected.to have_selector('.gl-bg-gray-100')
  end

  it 'has pricing info' do
    is_expected.to have_content(' 0')
    is_expected.not_to have_content(s_('BillingPlans|Billed annually'))
  end

  it 'does not have cta_link' do
    is_expected.not_to have_link(s_('BillingPlans|Learn more'))
  end

  context 'with trial as current plan' do
    let(:current_plan_code) { ::Plan::ULTIMATE_TRIAL }

    it 'does not have header for the current plan' do
      is_expected.not_to have_content(s_('BillingPlans|Your current plan'))
      is_expected.not_to have_selector('.gl-bg-gray-100')
    end
  end
end
