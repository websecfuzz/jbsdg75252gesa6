# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Groups > Add Ons > Discover Duo Enterprise > Hand Raise Lead', :js, :saas, feature_category: :activation do
  include Features::HandRaiseLeadHelpers

  let_it_be(:user) { create(:user, :with_namespace, user_detail_organization: 'GitLab') }
  let_it_be(:group) do
    create(:group_with_plan, trial_starts_on: 41.days.ago, trial_ends_on: 11.days.ago, owners: user)
  end

  let_it_be(:add_on_purchase) do
    create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :trial, namespace: group)
  end

  before do
    stub_saas_features(subscriptions_trials: true)

    sign_in(user)

    visit group_add_ons_discover_duo_enterprise_path(group)
  end

  it 'renders and submits when user interacts with hand raise lead trigger in the header' do # rubocop:disable RSpec/NoExpectationExample -- Expectations are in helper method
    within_testid('discover-header-actions') do
      find_button('Contact sales').click
    end

    fill_in_and_submit_hand_raise_lead(user, group, glm_content: 'discover-duo-enterprise')
  end

  it 'renders and submits when user interacts with hand raise lead trigger in the footer' do # rubocop:disable RSpec/NoExpectationExample -- Expectations are in helper method
    within_testid('discover-footer-actions') do
      find_button('Contact sales').click
    end

    fill_in_and_submit_hand_raise_lead(user, group, glm_content: 'discover-duo-enterprise')
  end
end
