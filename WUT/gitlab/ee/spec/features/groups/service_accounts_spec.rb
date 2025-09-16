# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Service accounts', feature_category: :user_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:group_owner) { create(:user, owner_of: [group]) }

  before do
    stub_ee_application_setting(allow_top_level_group_owners_to_create_service_accounts: true)
    stub_licensed_features(service_accounts: true)
  end

  describe 'landing page' do
    context 'when user is not a group owner' do
      it 'shows a 404 page' do
        sign_in(user)
        visit group_settings_service_accounts_path(group)
        expect(page).to have_css('h1', text: '404: Page not found')
      end
    end

    context 'when user is a group owner' do
      it 'shows a loading icon' do
        sign_in(group_owner)
        visit group_settings_service_accounts_path(group)
        expect(page).to have_css('.gl-sr-only', text: 'Loading')
      end
    end
  end
end
