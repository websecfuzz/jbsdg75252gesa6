# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Groups > Settings > Work items', :js, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user, owner_of: group) }

  before do
    sign_in(user)
    stub_licensed_features(work_item_status: true)
  end

  it 'shows system-defined lifecycles statuses' do
    visit group_settings_issues_path(group)

    click_button('Edit statuses')

    within_testid('category-triage') do
      click_button('Add status')
      fill_in 'status-name', with: 'Triage custom status'
      click_button('Add description')
      fill_in 'status-description', with: 'Deciding what to do with things'
      click_button('Save')
    end

    wait_for_requests

    expect(page).to have_content('Triage custom status')
  end
end
