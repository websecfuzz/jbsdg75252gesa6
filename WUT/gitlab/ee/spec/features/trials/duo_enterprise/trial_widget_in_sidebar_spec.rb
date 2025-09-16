# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Duo Enterprise Trial Widget in Sidebar', :saas, :js, feature_category: :acquisition do
  include SubscriptionPortalHelpers

  let_it_be(:user) { create(:user, :with_namespace, user_detail_organization: 'YMCA') }
  let_it_be(:group) { create(:group_with_plan, plan: :ultimate_plan, name: 'gitlab', owners: user) }

  before_all do
    create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :trial, namespace: group)
  end

  before do
    stub_saas_features(subscriptions_trials: true)

    sign_in(user)
  end

  context 'for the widget' do
    it 'shows the correct days remaining' do
      travel_to(15.days.from_now) do
        visit group_path(group)

        expect_widget_to_have_content('GitLab Duo Enterprise')
        expect(page).to have_content('45 days left in trial')
      end
    end

    context 'on the first day of trial' do
      it 'shows the correct days remaining' do
        freeze_time do
          visit group_path(group)

          expect(page).to have_content('60 days left in trial')
        end
      end
    end

    context 'on the last day of trial' do
      it 'shows the correct days remaining' do
        travel_to(59.days.from_now) do
          visit group_path(group)

          expect(page).to have_content('1 days left in trial')
        end
      end
    end

    context 'on the first day of expired trial' do
      it 'shows expired widget and dismisses it' do
        travel_to(60.days.from_now) do
          visit group_path(group)

          expect_widget_to_have_content('Upgrade')

          dismiss_widget

          expect(page).not_to have_content('Upgrade')

          page.refresh

          expect(page).not_to have_content('Upgrade')
        end
      end
    end

    def expect_widget_to_have_content(widget_title)
      within_testid(widget_menu_selector) do
        expect(page).to have_content(widget_title)
      end
    end

    def dismiss_widget
      within_testid(widget_root_element) do
        find_by_testid('close-icon').click
      end
    end
  end

  def widget_menu_selector
    'trial-widget-menu'
  end

  def widget_root_element
    'trial-widget-root-element'
  end
end
