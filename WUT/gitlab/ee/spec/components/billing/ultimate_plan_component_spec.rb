# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Billing::UltimatePlanComponent, :aggregate_failures, type: :component, feature_category: :subscription_management do
  include SubscriptionPortalHelpers

  let(:namespace) { build(:group) }
  let(:plans_data) { billing_plans_data.map { |plan| Hashie::Mash.new(plan) } }
  let(:current_plan) { Hashie::Mash.new(code: 'ultimate') }
  let(:instance) { described_class.new(plans_data: plans_data, namespace: namespace, current_plan: current_plan) }

  subject(:component) do
    render_inline(instance) && page
  end

  before do
    allow(instance).to receive(:plan_purchase_url).and_return('_purchase_url_')
  end

  it 'has plan specific content' do
    is_expected.to have_content(s_('BillingPlans|For enterprises looking to deliver software faster'))
    is_expected.to have_content(s_('BillingPlans|Everything from Premium, plus:'))
    is_expected.to have_content(s_('BillingPlans|Suggested Reviewers'))
  end

  it 'has pricing info' do
    is_expected.not_to have_content(' 0')
    is_expected.to have_content('Billed annually')
  end

  it 'has expected cta_link' do
    classes = 'btn-confirm btn-confirm-secondary'

    is_expected.to have_link(s_('BillingPlans|Upgrade to Ultimate'), href: '_purchase_url_', class: classes)
  end

  it 'does has learn more link' do
    is_expected.to have_link(s_('BillingPlans|Learn more about Ultimate'))
  end

  it 'has duo core feature' do
    within(find_by_testid('feature-list', context: component)) do
      expect(page).to have_content(s_('BillingPlans|AI Chat in the IDE'))
      expect(page).to have_content(s_('BillingPlans|AI Code Suggestions in the IDE'))
    end
  end

  it 'has expected tracking attributes' do
    attributes = {
      testid: 'upgrade-to-ultimate',
      action: 'click_button',
      label: 'plan_cta',
      property: 'ultimate'
    }

    is_expected.to have_tracking(attributes)
  end
end
