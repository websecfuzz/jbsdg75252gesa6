# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Duo Pro Trial Widget in Sidebar', :saas, :js, feature_category: :acquisition do
  include SubscriptionPortalHelpers
  include Features::HandRaiseLeadHelpers

  let_it_be(:user) { create(:user, :with_namespace, user_detail_organization: 'YMCA') }
  let_it_be(:group) { create(:group_with_plan, plan: :ultimate_plan, name: 'gitlab', owners: user) }

  before_all do
    create(:gitlab_subscription_add_on_purchase, :duo_pro, :trial, namespace: group)
  end

  before do
    stub_saas_features(subscriptions_trials: true)
    sign_in(user)
  end

  context 'for the widget' do
    it 'shows the correct days remaining' do
      travel_to(15.days.from_now) do
        visit group_path(group)

        expect_widget_title_to_be('GitLab Duo Pro Trial')
        expect_days_remaining_to_be('45 days left in trial')
      end
    end

    context 'on the first day of trial' do
      it 'shows the correct days remaining' do
        freeze_time do
          visit group_path(group)

          expect_widget_title_to_be('GitLab Duo Pro Trial')
          expect_days_remaining_to_be('60 days left in trial')
        end
      end
    end

    context 'on the last day of trial' do
      it 'shows 1 day remaining' do
        travel_to(59.days.from_now) do
          visit group_path(group)

          expect_widget_title_to_be('GitLab Duo Pro Trial')
          expect_days_remaining_to_be('1 days left in trial')
        end
      end
    end

    context 'on the first day of expired trial' do
      before do
        stub_signing_key
        stub_application_setting(check_namespace_plan: true)
        stub_subscription_permissions_data(group.id)
        stub_licensed_features(code_suggestions: true)
      end

      it 'shows expired widget and dismisses it' do
        travel_to(60.days.from_now) do
          visit group_usage_quotas_path(group)

          expect_widget_title_to_be('Your trial of GitLab Duo Pro has ended')
          expect(page).to have_content('Upgrade')

          dismiss_widget

          expect(page).not_to have_content('Your trial of GitLab Duo Pro has ended')

          visit group_add_ons_discover_duo_pro_path(group)

          expect(page).to have_content('Discover Duo Pro')
          expect(page).not_to have_content('Your trial of GitLab Duo Pro has ended')
        end
      end
    end

    def expect_widget_title_to_be(widget_title)
      within_testid('trial-widget-menu') do
        expect(page).to have_selector('[data-testid="widget-title"]', text: widget_title)
      end
    end

    def expect_days_remaining_to_be(days_text)
      within_testid('trial-widget-menu') do
        expect(page).to have_content(days_text)
      end
    end

    def dismiss_widget
      within_testid('trial-widget-root-element') do
        find_by_testid('dismiss-btn').click
      end
    end
  end
end
