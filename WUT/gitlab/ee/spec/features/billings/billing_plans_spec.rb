# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Billing plan pages', :feature, :saas, :js, feature_category: :subscription_management do
  include SubscriptionPortalHelpers
  include Features::HandRaiseLeadHelpers
  include Features::BillingPlansHelpers

  let(:user) { create(:user, first_name: 'James', last_name: 'Bond', user_detail_organization: 'ACME') }
  let(:auditor) { create(:auditor, first_name: 'James', last_name: 'Bond', user_detail_organization: 'ACME') }
  let(:namespace) { user.namespace }
  let(:free_plan) { create(:free_plan) }
  let(:bronze_plan) { create(:bronze_plan) }
  let(:premium_plan) { create(:premium_plan) }
  let(:ultimate_plan) { create(:ultimate_plan) }

  let(:plans_data) { billing_plans_data }

  before do
    stub_signing_key
    stub_application_setting(check_namespace_plan: true)

    stub_billing_plans(nil)
    stub_billing_plans(namespace.id, plan.name, plans_data.to_json)
    stub_subscription_management_data(namespace.id)
    stub_temporary_extension_data(namespace.id)
    stub_get_billing_account_details

    sign_in(user)
  end

  def external_upgrade_url(namespace, plan)
    subscription_portal_url = ::Gitlab::Routing.url_helpers.subscription_portal_url

    if Plan::PAID_HOSTED_PLANS.include?(plan.name)
      "#{subscription_portal_url}/gitlab/namespaces/#{namespace.id}/upgrade/#{plan.name}-external-id"
    end
  end

  shared_examples 'does not display the billing plans' do
    it 'does not display the plans' do
      expect(page).not_to have_selector("[data-testid='billing-plans']")
    end
  end

  shared_examples 'upgradable plan' do
    before do
      visit page_path
    end

    it 'displays the upgrade link' do
      page.within('.content') do
        expect(page).to have_link('Upgrade', href: external_upgrade_url(namespace, plan))
      end
    end
  end

  shared_examples 'can not contact sales' do
    before do
      visit page_path
    end

    it 'does not render in-app hand raise lead' do
      should_have_hand_raise_lead_button
    end
  end

  shared_examples 'non-upgradable plan' do
    before do
      visit page_path
    end

    it 'does not display the upgrade link' do
      page.within('.content') do
        expect(page).not_to have_link('Upgrade', href: external_upgrade_url(namespace, plan))
      end
    end
  end

  shared_examples 'downgradable plan' do
    before do
      visit page_path
    end

    it 'displays the downgrade link' do
      page.within('.content') do
        expect(page).to have_content('downgrade your plan')
        expect(page).to have_link('Customer Support', href: EE::CUSTOMER_SUPPORT_URL)
      end
    end
  end

  shared_examples 'plan with header' do
    before do
      visit page_path
    end

    it 'displays header' do
      page.within('.billing-plan-header') do
        expect(page).to have_content("#{user.username} you are currently using the #{plan.name.titleize} Plan.")

        expect(page).to have_css('.billing-plan-logo img')
      end
    end
  end

  shared_examples 'plan with subscription table' do
    before do
      visit page_path
    end

    it 'displays subscription table' do
      expect(page).to have_selector('.js-subscription-table')
    end
  end

  shared_examples 'subscription table with management buttons' do
    before do
      visit page_path
    end

    it 'displays subscription table' do
      expect(page).to have_link('Add seats')
      expect(page).to have_link('Manage')
      expect(page).to have_link('Renew')
    end
  end

  shared_examples 'subscription table without management buttons' do
    before do
      visit page_path
    end

    it 'displays subscription table' do
      expect(page).not_to have_link('Manage')
      expect(page).not_to have_link('Add seats')
      expect(page).not_to have_link('Renew')
    end
  end

  shared_examples 'used seats rendering for non paid subscriptions' do
    before do
      visit page_path
    end

    it 'displays the number of seats' do
      page.within('.js-subscription-table') do
        expect(page).to have_selector('p.property-value.gl-mt-2.gl-mb-0.number', text: '1')
      end
    end
  end

  context 'users profile billing page' do
    let(:page_path) { profile_billings_path }

    context 'on free' do
      let(:plan) { free_plan }

      before do
        visit page_path
      end

      it 'displays the correct call to action', :js do
        page.within('.billing-plan-header') do
          expect(page).to have_content('Looking to purchase or manage a subscription for your group? Navigate to your group and go to Settings > Billing')
          expect(page).to have_link('group', href: dashboard_groups_path)
        end
      end

      it_behaves_like 'does not display the billing plans'
      it_behaves_like 'plan with subscription table'
    end

    context 'on bronze plan' do
      let(:plan) { bronze_plan }
      let(:premium_plan_data) { plans_data.find { |plan_data| plan_data[:id] == 'premium-external-id' } }
      let!(:subscription) { create(:gitlab_subscription, namespace: namespace, hosted_plan: plan, seats: 15) }

      it_behaves_like 'plan with header'
      it_behaves_like 'downgradable plan'
      it_behaves_like 'can not contact sales'
      it_behaves_like 'plan with subscription table'

      context 'with an active deprecated plan' do
        let(:legacy_plan) { plans_data.find { |plan_data| plan_data[:id] == 'bronze-external-id' } }
        let(:expected_card_header) { "#{legacy_plan[:name]} (Legacy)" }

        it 'renders the plan card marked as Legacy' do
          visit page_path
          within_testid('billing-plans') do
            panels = page.all('.card')
            expect(panels.length).to eq(plans_data.length)

            panel_with_legacy_plan = find_by_testid("plan-card-#{legacy_plan[:code]}")

            expect(panel_with_legacy_plan.find('.card-header')).to have_content(expected_card_header)
            expect(panel_with_legacy_plan.find('.card-body')).to have_link('frequently asked questions')
          end
        end
      end
    end

    context 'on premium plan' do
      let(:plan) { premium_plan }

      let!(:subscription) { create(:gitlab_subscription, namespace: namespace, hosted_plan: plan, seats: 15) }

      it_behaves_like 'plan with header'
      it_behaves_like 'downgradable plan'
      it_behaves_like 'upgradable plan'
      it_behaves_like 'can not contact sales'
      it_behaves_like 'plan with subscription table'
    end

    context 'on ultimate plan' do
      let(:plan) { ultimate_plan }

      let!(:subscription) { create(:gitlab_subscription, namespace: namespace, hosted_plan: plan, seats: 15) }

      it_behaves_like 'plan with header'
      it_behaves_like 'downgradable plan'
      it_behaves_like 'non-upgradable plan'
      it_behaves_like 'plan with subscription table'
    end

    context 'when CustomersDot is unavailable' do
      let(:plan) { ultimate_plan }
      let!(:subscription) { create(:gitlab_subscription, namespace: namespace, hosted_plan: plan) }

      before do
        stub_billing_plans(namespace.id, plan.name, raise_error: 'Connection refused')
      end

      it 'renders an error page' do
        visit page_path

        expect(page).to have_content("Subscription service outage")
      end
    end
  end

  context 'users profile billing page with a trial' do
    let(:page_path) { profile_billings_path }

    context 'on free' do
      let(:plan) { free_plan }

      let!(:subscription) do
        create(
          :gitlab_subscription,
          namespace: namespace,
          hosted_plan: plan,
          trial: true,
          trial_starts_on: Date.current,
          trial_ends_on: Date.current.tomorrow,
          seats: 15
        )
      end

      before do
        visit page_path
      end

      it_behaves_like 'does not display the billing plans'
    end

    context 'on bronze plan' do
      let(:plan) { bronze_plan }

      let!(:subscription) { create(:gitlab_subscription, namespace: namespace, hosted_plan: plan, seats: 15) }

      it_behaves_like 'plan with header'
      it_behaves_like 'downgradable plan'
      it_behaves_like 'can not contact sales'
    end

    context 'on ultimate plan' do
      let(:plan) { ultimate_plan }

      let!(:subscription) { create(:gitlab_subscription, namespace: namespace, hosted_plan: plan, seats: 15) }

      it_behaves_like 'plan with header'
      it_behaves_like 'downgradable plan'
      it_behaves_like 'non-upgradable plan'
    end
  end

  context 'group billing page' do
    let(:namespace) { create(:group) }

    before do
      namespace.add_owner(user)
      # post_create_member_hook creates a subscription due to a license check.
      # We delete it here so that subscription creation in the tests below do not violate the unique constraint
      namespace.gitlab_subscription.destroy!
    end

    context 'when a group is the top-level group' do
      let(:page_path) { group_billings_path(namespace) }

      context 'on ultimate' do
        let(:plan) { ultimate_plan }

        let!(:subscription) { create(:gitlab_subscription, namespace: namespace, hosted_plan: plan, seats: 15) }

        it 'displays plan header' do
          visit page_path

          page.within('.billing-plan-header') do
            expect(page).to have_content("#{namespace.name} is currently using the Ultimate Plan")

            expect(page).to have_css('.billing-plan-logo .gl-avatar-identicon')
          end
        end

        it_behaves_like 'does not display the billing plans'
        it_behaves_like 'plan with subscription table'
        it_behaves_like 'subscription table with management buttons'
      end

      context 'on bronze' do
        let(:plan) { bronze_plan }

        let!(:subscription) { create(:gitlab_subscription, namespace: namespace, hosted_plan: plan, seats: 15) }

        before do
          visit page_path
        end

        it 'displays plan header' do
          page.within('.billing-plan-header') do
            expect(page).to have_content("#{namespace.name} is currently using the Bronze Plan")

            expect(page).to have_css('.billing-plan-logo .gl-avatar-identicon')
          end
        end

        it 'does display the billing plans table' do
          expect(page).to have_selector("[data-testid='billing-plans']")
        end

        context 'when submitting hand raise lead' do
          it 'displays the in-app hand raise lead' do
            click_premium_contact_sales_button_and_submit_form(user, namespace)
          end
        end

        it_behaves_like 'plan with subscription table'
      end

      context 'on free' do
        let(:plan) { free_plan }

        it 'submits hand raise lead form' do
          visit page_path

          click_button 'Talk to an expert'

          fill_in_and_submit_hand_raise_lead(user, namespace, glm_content: 'billing-group')
        end
      end

      context 'on trial' do
        let(:plan) { free_plan }

        let!(:subscription) do
          create(:gitlab_subscription, :active_trial,
            namespace: namespace,
            hosted_plan: premium_plan,
            seats: 15
          )
        end

        before do
          visit page_path
        end

        it 'displays the billing plans table' do
          expect(page).to have_selector("[data-testid='billing-plans']")
        end

        it_behaves_like 'non-upgradable plan'
        it_behaves_like 'used seats rendering for non paid subscriptions'
        it_behaves_like 'plan with subscription table'
        it_behaves_like 'subscription table with management buttons'
      end

      context 'with auditor user' do
        let(:plan) { ultimate_plan }
        let!(:subscription) { create(:gitlab_subscription, namespace: namespace, hosted_plan: plan, seats: 15) }

        before do
          stub_licensed_features(auditor_user: true)

          sign_in(auditor)
        end

        it_behaves_like 'does not display the billing plans'
        it_behaves_like 'plan with subscription table'
        it_behaves_like 'subscription table without management buttons'
      end
    end

    context 'when a group is the subgroup' do
      let(:namespace) { create(:group_with_plan) }
      let(:plan) { namespace.actual_plan }
      let(:subgroup) { create(:group, parent: namespace) }

      it 'shows the subgroup page context for billing', :aggregate_failures do
        visit group_billings_path(subgroup)

        expect(page).to have_text('is currently using the')
        expect(page).to have_text('This group uses the plan associated with its parent group')
        expect(page).to have_link('Manage plan')
        expect(page).not_to have_selector("[data-testid='billing-plans']")
      end
    end

    context 'seat refresh button' do
      let_it_be(:developer) { create(:user) }
      let_it_be(:guest) { create(:user) }

      let!(:subscription) { create(:gitlab_subscription, namespace: namespace, hosted_plan: plan, seats: 1) }

      let(:plan) { ultimate_plan }

      before do
        namespace.add_developer(developer)
        namespace.add_guest(guest)

        visit group_billings_path(namespace)
      end

      it 'updates seat counts on click' do
        expect(seats_in_subscription).to eq '1'
        expect(seats_currently_in_use).to eq '0'
        expect(max_seats_used).to eq '0'
        expect(seats_owed).to eq '0'

        click_button 'Refresh Seats'
        wait_for_requests

        expect(seats_in_subscription).to eq '1'
        expect(seats_currently_in_use).to eq '2'
        expect(max_seats_used).to eq '2'
        expect(seats_owed).to eq '1'
      end

      def seats_in_subscription
        find_by_testid('seats-in-subscription').text
      end

      def seats_currently_in_use
        find_by_testid('seats-currently-in-use').text
      end

      def max_seats_used
        find_by_testid('max-seats-used').text
      end

      def seats_owed
        find_by_testid('seats-owed').text
      end
    end
  end

  context 'with unexpected JSON' do
    let(:plan) { premium_plan }

    let!(:subscription) { create(:gitlab_subscription, namespace: namespace, hosted_plan: plan, seats: 15) }

    let(:plans_data) do
      [
        {
          name: "Superhero",
          price_per_month: 999.0,
          free: true,
          code: "not-found",
          price_per_year: 111.0,
          purchase_link: {
            action: "upgrade",
            href: "http://customers.test.host/subscriptions/new?plan_id=super_hero_id"
          },
          features: []
        }
      ]
    end

    before do
      visit profile_billings_path
    end

    it 'renders no header for missing plan' do
      expect(page).not_to have_css('.billing-plan-header')
    end

    it 'displays all plans' do
      within_testid('billing-plans') do
        panels = page.all('.card')
        expect(panels.length).to eq(plans_data.length)
        plans_data.each_with_index do |data, index|
          expect(panels[index].find('.card-header')).to have_content(data[:name])
        end
      end
    end
  end
end
