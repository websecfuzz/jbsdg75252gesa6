# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Groups > Billing', :js, :saas, feature_category: :subscription_management do
  include StubRequests
  include SubscriptionPortalHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:auditor) { create(:auditor) }
  let_it_be(:group) { create(:group, owners: user, guests: auditor) }
  let_it_be(:bronze_plan) { create(:bronze_plan) }

  def formatted_date(date)
    date.strftime("%b %-d, %Y")
  end

  def subscription_table
    '.subscription-table'
  end

  before do
    stub_signing_key
    stub_application_setting(check_namespace_plan: true)
    stub_get_billing_account_details

    sign_in(user)
  end

  shared_examples 'hides search settings' do
    it 'does not have search settings' do
      visit group_billings_path(group)

      expect(page).not_to have_field(placeholder: SearchHelpers::INPUT_PLACEHOLDER)
    end
  end

  context 'when CustomersDot is available' do
    before do
      stub_billing_plans(group.id, plan)
    end

    context 'with a free plan' do
      let(:plan) { 'free' }
      let!(:subscription) do
        create(:gitlab_subscription, namespace: group, hosted_plan: nil, seats: 15)
      end

      it_behaves_like 'hides search settings'

      it 'shows the proper title and subscription data' do
        visit group_billings_path(group)

        expect(page).to have_content("#{group.name} is currently using the Free Plan")
        expect(page).to have_text('Not the group')
        expect(page).to have_link('Switch to a different group', href: dashboard_groups_path)

        expect(page).not_to have_link("Manage")
        expect(page).not_to have_link("Add seats")
        expect(page).not_to have_link("Renew")
      end

      context 'with targeted message' do
        before do
          create(:targeted_message_namespace, namespace: group)
        end

        it 'is not shown to non-owner' do
          sign_in(auditor)
          visit group_billings_path(group)

          expect(page).not_to have_content("Get access to both GitLab Premium and Duo Pro")
        end

        it 'is shown to owner' do
          visit group_billings_path(group)

          expect(page).to have_content("Get access to both GitLab Premium and Duo Pro")
        end
      end

      context 'with disabled targeted message' do
        before do
          stub_feature_flags(targeted_messages_admin_ui: false)
          create(:targeted_message_namespace, namespace: group)
        end

        it 'is not shown' do
          visit group_billings_path(group)

          expect(page).not_to have_content("Get access to both GitLab Premium and Duo Pro")
        end
      end
    end

    context 'with a paid plan' do
      let(:plan) { 'bronze' }

      let_it_be(:subscription) do
        create(:gitlab_subscription, end_date: Date.today + 14.days, namespace: group, hosted_plan: bronze_plan, seats: 15)
      end

      context 'with all available management activities' do
        before do
          stub_subscription_management_data(group.id)
          stub_temporary_extension_data(group.id)
        end

        it_behaves_like 'hides search settings'

        it 'shows the proper title and subscription data' do
          subscription_portal_url = ::Gitlab::Routing.url_helpers.subscription_portal_url

          extra_seats_url = "#{subscription_portal_url}/gitlab/namespaces/#{group.id}/extra_seats"
          renew_url = "#{subscription_portal_url}/gitlab/namespaces/#{group.id}/renew"
          manage_url = "#{subscription_portal_url}/subscriptions"

          visit group_billings_path(group)

          expect(page).to have_content("#{group.name} is currently using the Bronze Plan")
          within subscription_table do
            expect(page).to have_content("start date #{formatted_date(subscription.start_date)}")
            expect(page).to have_content("end date #{formatted_date(subscription.end_date)}")
            expect(page).to have_link("Manage", href: manage_url)
            expect(page).to have_link("Add seats", href: extra_seats_url)
            expect(page).to have_link("Renew", href: renew_url)
            expect(page).to have_link("See usage", href: group_usage_quotas_path(group, anchor: 'seats-quota-tab'))
          end
        end
      end

      context 'with disabled seats and review buttons' do
        before do
          stub_subscription_management_data(group.id, can_add_seats: false, can_renew: false)
          stub_temporary_extension_data(group.id)
        end

        it 'hides add seats and renew buttons' do
          visit group_billings_path(group)

          within subscription_table do
            expect(page).not_to have_link("Add seats")
            expect(page).not_to have_link("Renew")
          end
        end
      end
    end

    context 'with a legacy paid plan' do
      before do
        stub_subscription_management_data(group.id)
        stub_temporary_extension_data(group.id)
      end

      let(:plan) { 'bronze' }

      let!(:subscription) do
        create(:gitlab_subscription, end_date: 1.week.ago, namespace: group, hosted_plan: bronze_plan, seats: 15)
      end

      it 'shows the proper title and subscription data' do
        visit group_billings_path(group)

        manage_url = "#{subscription_portal_url}/subscriptions"

        expect(page).to have_content("#{group.name} is currently using the Bronze Plan")
        within subscription_table do
          expect(page).to have_link("Manage", href: manage_url)
        end
      end
    end
  end

  context 'when CustomersDot is unavailable' do
    before do
      stub_billing_plans(group.id, plan, raise_error: 'Connection refused')
    end

    let(:plan) { 'bronze' }

    let_it_be(:subscription) do
      create(:gitlab_subscription, namespace: group, hosted_plan: bronze_plan, seats: 15)
    end

    it 'renders an error page' do
      visit group_billings_path(group)

      expect(page).to have_content("Subscription service outage")
    end
  end
end
