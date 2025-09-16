# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'groups/billings/index', :saas, :aggregate_failures, feature_category: :subscription_management do
  include RenderedHtml
  include SubscriptionPortalHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group_with_plan, plan: :free_plan) }
  let_it_be(:plans_data) { billing_plans_data.map { |plan| Hashie::Mash.new(plan) } }

  before do
    stub_signing_key
    stub_get_billing_account_details
    allow(view).to receive(:current_user).and_return(user)
    assign(:group, group)
    assign(:plans_data, plans_data)
  end

  context 'when the group is a subgroup' do
    let(:top_level_group) { build(:group) }

    before do
      assign(:top_level_group, top_level_group)
    end

    context 'for the unlimited members trial alert' do
      it 'does not set content_for :hide_explore_paid_plans_button' do
        render

        expect(view.content_for(:hide_explore_paid_plans_button).to_s).not_to eq('true')
      end
    end
  end

  context 'when the group is the top level' do
    context 'for the unlimited members trial alert' do
      it 'sets content_for :hide_explore_paid_plans_button to true' do
        render

        expect(view.content_for(:hide_explore_paid_plans_button).to_s).to eq('true')
      end
    end

    shared_examples 'without duo enterprise trial alert' do
      it 'does not render the component' do
        render

        expect(rendered).not_to have_css('[data-testid="duo-enterprise-trial-alert"]')
      end
    end

    shared_examples 'with duo enterprise trial alert' do
      it 'renders the component' do
        render

        expect(rendered).to have_css('[data-testid="duo-enterprise-trial-alert"]')
      end
    end

    shared_examples 'without ultimate trial cta alert' do
      it 'does not render the component' do
        render

        expect(rendered).not_to have_link('Start a free Ultimate trial')
      end
    end

    context 'with free plan' do
      it 'renders the billing page' do
        render

        expect(rendered).not_to have_selector('#js-billing-plans')
        expect(rendered).to have_text('is currently using the')
        expect(rendered).to have_text('Not the group')
        expect(rendered).to have_link('Switch to a different group', href: dashboard_groups_path)

        page = rendered_html

        # free
        scoped_node = page.find("[data-testid='plan-card-free']")

        expect(scoped_node).to have_content('Your current plan')
        expect(scoped_node).to have_content('Free')
        expect(scoped_node).to have_content('Use GitLab for personal projects')

        # premium
        scoped_node = page.find("[data-testid='plan-card-premium']")

        expect(scoped_node).to have_content('Recommended')
        expect(scoped_node).to have_content('Premium')
        expect(scoped_node).to have_content('For scaling organizations and multi-team usage')
        expect(scoped_node).to have_link('Upgrade to Premium')

        # ultimate
        scoped_node = page.find("[data-testid='plan-card-ultimate']")

        expect(scoped_node).to have_content('Ultimate')
        expect(scoped_node).to have_content('For enterprises looking to deliver software faster')
        expect(scoped_node).to have_link('Upgrade to Ultimate')
      end

      it 'has tracking items set as expected' do
        render

        expect(rendered).to have_tracking(action: 'render')
        expect(rendered).to have_tracking(action: 'click_button', label: 'view_all_groups')
      end

      it_behaves_like 'with duo enterprise trial alert'
      it_behaves_like 'without ultimate trial cta alert'

      context 'with an expired trial' do
        let_it_be(:group) do
          create(:group_with_plan,
            plan: :free_plan,
            trial: true,
            trial_starts_on: 1.month.ago,
            trial_ends_on: Date.yesterday)
        end

        it_behaves_like 'without ultimate trial cta alert'
        it_behaves_like 'with duo enterprise trial alert'
      end
    end

    context 'with an active trial' do
      let_it_be(:group) do
        create(:group_with_plan,
          plan: :ultimate_trial_plan,
          trial: true,
          trial_starts_on: 1.month.ago,
          trial_ends_on: 10.days.from_now)
      end

      it_behaves_like 'without ultimate trial cta alert'
      it_behaves_like 'without duo enterprise trial alert'
    end

    context 'with a paid plan' do
      let_it_be(:group) { create(:group_with_plan, plan: :ultimate_plan) }

      it 'renders the billing plans' do
        render

        expect(rendered).to render_template('_top_level_billing_plan_header')
        expect(rendered).to render_template('shared/billings/_billing_plans')
        expect(rendered).to have_selector('#js-billing-plans')
      end

      it_behaves_like 'with duo enterprise trial alert'
    end

    context 'when purchasing a plan' do
      before do
        allow(view).to receive(:params).and_return(purchased_quantity: quantity)
        allow(view).to receive(:plan_title).and_return('Bronze')
      end

      let(:quantity) { '1' }

      it 'tracks purchase banner', :snowplow do
        render

        expect_snowplow_event(
          category: 'groups:billings',
          action: 'render',
          label: 'purchase_confirmation_alert_displayed',
          namespace: group,
          user: user
        )
      end

      context 'with a single user' do
        it 'displays the correct notification for 1 user' do
          render

          expect(rendered).to have_text('You\'ve successfully purchased the Bronze plan subscription for 1 user and ' \
                                    'you\'ll receive a receipt by email. Your purchase may take a minute to sync, ' \
                                    'refresh the page if your subscription details haven\'t displayed yet.')
        end
      end

      context 'with multiple users' do
        let(:quantity) { '2' }

        it 'displays the correct notification for 2 users' do
          render

          expect(rendered).to have_text('You\'ve successfully purchased the Bronze plan subscription for 2 users and ' \
                                    'you\'ll receive a receipt by email. Your purchase may take a minute to sync, ' \
                                    'refresh the page if your subscription details haven\'t displayed yet.')
        end
      end
    end
  end
end
