# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'SAML group links', feature_category: :system_access do
  include ListboxHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }

  before do
    group.add_owner(user)
    sign_in(user)
  end

  context 'when SAML group links is available' do
    before do
      stub_licensed_features(group_saml: true, saml_group_sync: true)

      create(:saml_provider, group: group, enabled: true)

      visit group_saml_group_links_path(group)
    end

    context 'with existing records' do
      let_it_be(:group_link1) { create(:saml_group_link, group: group, saml_group_name: 'Web Developers') }
      let_it_be(:group_link2) do
        create(:saml_group_link, group: group, saml_group_name: 'Web Managers', assign_duo_seats: true)
      end

      let_it_be(:other_group_link) { create(:saml_group_link, group: create(:group), saml_group_name: 'Other Group') }

      it 'lists active links' do
        expect(page).to have_content('SAML Group Name: Web Developers')
        expect(page).to have_content('SAML Group Name: Web Managers')
      end

      it 'does not show Duo seat assignment features' do
        expect(page).not_to have_content(s_('GroupSAML|Assign GitLab Duo seats to users in this group'))
        expect(page).not_to have_content(s_('GroupSAML|with GitLab Duo seat assignment'))
      end

      it 'does not list links for other groups' do
        expect(page).not_to have_content('SAML Group Name: Other Group')
      end

      context 'when Duo seat assignment is available' do
        let_it_be(:add_on_purchase) do
          create(
            :gitlab_subscription_add_on_purchase,
            :duo_pro,
            expires_on: 1.week.from_now.to_date,
            namespace: group
          )
        end

        before do
          stub_saas_features(gitlab_duo_saas_only: true)

          # Reload the page since the above actions that must be run before page load
          visit group_saml_group_links_path(group)
        end

        it 'shows Duo seat assignment features' do
          expect(page).to have_content(s_('GroupSAML|Assign GitLab Duo seats to users in this group'))
          expect(page).to have_content(s_('GroupSAML|with GitLab Duo seat assignment'))
        end
      end
    end

    it 'adds new SAML group link with a standard role', :js do
      within_testid('new-saml-group-link') do
        fill_in 'SAML Group Name', with: 'Acme SAML Group'
        toggle_listbox
        select_listbox_item 'Developer'

        click_button 'Save'
      end

      expect(page).not_to have_content('No active SAML group links')
      expect(page).to have_content('SAML Group Name: Acme SAML Group')
      expect(page).to have_content('as Developer')
    end
  end

  context 'when custom roles are enabled' do
    before do
      stub_licensed_features(group_saml: true, saml_group_sync: true, custom_roles: true)
      stub_saas_features(gitlab_com_subscriptions: true)

      create(:saml_provider, group: group, enabled: true)
      create(:member_role, namespace: group, name: 'Custom')

      visit group_saml_group_links_path(group)
    end

    it 'adds new SAML group link with a custom role', :js do
      within_testid('new-saml-group-link') do
        fill_in 'SAML Group Name', with: 'Acme SAML Group'
        toggle_listbox
        select_listbox_item 'Custom'

        click_button 'Save'
      end

      expect(page).not_to have_content('No active SAML group links')
      expect(page).to have_content('SAML Group Name: Acme SAML Group')
      expect(page).to have_content('as Custom')
    end
  end
end
