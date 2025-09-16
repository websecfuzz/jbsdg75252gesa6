# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gitlab_subscriptions/groups/edit', feature_category: :subscription_management do
  let(:group) { build_stubbed(:group) }
  let(:user) { build_stubbed(:user) }
  let(:quantity) { '1' }

  before do
    assign(:group, group)

    allow(view).to receive_messages(
      params: { quantity: quantity },
      plan_title: 'Bronze',
      group_path: '',
      subscriptions_groups_path: '',
      current_user: user
    )
  end

  it 'renders the desired page header content' do
    render

    expect(rendered).to have_text(_('Create your group'))
  end

  it 'tracks purchase banner', :snowplow do
    render

    expect_snowplow_event(
      category: 'gitlab_subscriptions:groups',
      action: 'render',
      label: 'purchase_confirmation_alert_displayed',
      namespace: group,
      user: user
    )
  end

  context 'for a single user' do
    it 'displays the correct notification for 1 user' do
      render

      expect(rendered).to have_text(
        'You\'ve successfully purchased the Bronze plan subscription for 1 user and ' \
          'you\'ll receive a receipt by email. Your purchase may take a minute to sync, ' \
          'refresh the page if your subscription details haven\'t displayed yet.'
      )
    end
  end

  context 'for multiple users' do
    let(:quantity) { '2' }

    it 'displays the correct notification for 2 users' do
      render

      expect(rendered).to have_text(
        'You\'ve successfully purchased the Bronze plan subscription for 2 users and ' \
          'you\'ll receive a receipt by email. Your purchase may take a minute to sync, ' \
          'refresh the page if your subscription details haven\'t displayed yet.')
    end
  end
end
