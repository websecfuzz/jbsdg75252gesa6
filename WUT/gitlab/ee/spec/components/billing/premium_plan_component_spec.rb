# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Billing::PremiumPlanComponent, :aggregate_failures, type: :component, feature_category: :subscription_management do
  include SubscriptionPortalHelpers

  let(:namespace) { build(:group) }
  let(:plans_data) { billing_plans_data.map { |plan| Hashie::Mash.new(plan) } }
  let(:current_plan) { Hashie::Mash.new(code: 'premium') }
  let(:instance) { described_class.new(plans_data: plans_data, namespace: namespace, current_plan: current_plan) }

  subject(:component) do
    render_inline(instance) && page
  end

  before do
    allow(instance).to receive(:plan_purchase_url).and_return('_purchase_url_')
  end

  it 'has plan specific content' do
    is_expected.to have_content(s_('BillingPlans|For scaling organizations and multi-team usage'))
    is_expected.to have_content(s_('BillingPlans|Everything from Free, plus:'))
    is_expected.to have_content(s_('BillingPlans|Code Ownership and Protected Branches'))
  end

  it 'has header for the current plan' do
    is_expected.to have_content(s_('BillingPlans|Recommended'))
    is_expected.to have_selector('.gl-bg-purple-500')
  end

  it 'has pricing info' do
    is_expected.not_to have_content(' 0')
    is_expected.to have_content(s_('BillingPlans|Billed annually'))
  end

  it 'has expected cta_link' do
    is_expected.to have_link(s_('BillingPlans|Upgrade to Premium'), href: '_purchase_url_', class: 'btn-confirm')
    is_expected.not_to have_selector('.btn-confirm-secondary')
  end

  it 'does has learn more link' do
    is_expected.to have_link(s_('BillingPlans|Learn more about Premium'))
  end

  it 'has duo core feature' do
    within(find_by_testid('feature-list', context: component)) do
      expect(page).to have_content(s_('BillingPlans|AI Chat in the IDE'))
      expect(page).to have_content(s_('BillingPlans|AI Code Suggestions in the IDE'))
    end
  end

  it 'has expected tracking attributes' do
    attributes = {
      testid: 'upgrade-to-premium',
      action: 'click_button',
      label: 'plan_cta',
      property: 'premium'
    }

    is_expected.to have_tracking(attributes)
  end
end
