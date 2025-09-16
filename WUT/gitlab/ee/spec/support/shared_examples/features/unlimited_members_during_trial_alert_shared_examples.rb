# frozen_string_literal: true

RSpec.shared_examples_for 'unlimited members during trial alert' do
  include Features::InviteMembersModalHelpers
  include SubscriptionPortalHelpers

  before do
    create(:callout, user: user, feature_name: :duo_chat_callout)
  end

  it 'does not display alert after user dismisses' do
    visit page_path

    find('[data-testid="hide-unlimited-members-during-trial-alert"]').click

    wait_for_all_requests

    expect(page).to have_selector('a[aria-current="page"]', text: current_page_label)
    expect(page).not_to have_selector(alert_selector)
  end
end
