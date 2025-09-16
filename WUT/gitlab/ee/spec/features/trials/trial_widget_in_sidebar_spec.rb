# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Trial Widget in Sidebar', :saas, :js, feature_category: :acquisition do
  include SubscriptionPortalHelpers

  let_it_be(:user) { create(:user, :with_namespace, user_detail_organization: 'YMCA') }

  let_it_be(:group) do
    create(
      :group_with_plan,
      plan: :ultimate_trial_plan,
      trial: true,
      trial_starts_on: Date.current,
      trial_ends_on: 60.days.from_now,
      owners: user
    )
  end

  let_it_be(:add_on_purchase) do
    create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :trial, namespace: group)
  end

  before do
    stub_saas_features(subscriptions_trials: true)
    sign_in(user)
  end

  context 'when duo enterprise is available' do
    it 'shows the correct days remaining on the first day of trial' do
      freeze_time do
        visit group_path(group)

        expect_widget_to_have_content('Ultimate with GitLab Duo Enterprise')
        expect(page).to have_content('60 days left in trial')
      end
    end

    it 'shows the correct trial type and days remaining' do
      travel_to(15.days.from_now) do
        visit group_path(group)

        expect_widget_to_have_content('Ultimate with GitLab Duo Enterprise')
        expect(page).to have_content('45 days left in trial')
      end

      travel_to(59.days.from_now) do
        visit group_path(group)

        expect_widget_to_have_content('Ultimate with GitLab Duo Enterprise')
        expect(page).to have_content('1 days left in trial')
      end
    end

    context 'when widget is expired' do
      let_it_be(:group_with_expired_trial) do
        create(
          :group_with_plan,
          plan: :free_plan,
          trial: true,
          trial_starts_on: Date.current,
          trial_ends_on: 60.days.from_now,
          owners: user
        )
      end

      before_all do
        create(
          :gitlab_subscription_add_on_purchase,
          :trial,
          namespace: group_with_expired_trial,
          add_on: add_on_purchase.add_on
        )
      end

      it 'shows upgrade after trial expiration' do
        travel_to(60.days.from_now) do
          visit group_path(group_with_expired_trial)

          expect_widget_to_have_content('Your trial of Ultimate with GitLab Duo Enterprise has ended')
          expect(page).to have_content('Upgrade')
        end
      end

      it 'and allows dismissal on the first day after trial expiration' do
        travel_to(60.days.from_now) do
          visit group_path(group_with_expired_trial)

          expect_widget_to_have_content('Your trial of Ultimate with GitLab Duo Enterprise has ended')
          expect(page).to have_content('Upgrade')

          dismiss_widget

          expect(page).not_to have_content('Upgrade')

          page.refresh

          expect(page).not_to have_content('Upgrade')
        end
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

  def widget_menu_selector
    'trial-widget-menu'
  end

  def widget_root_element
    'trial-widget-root-element'
  end
end
