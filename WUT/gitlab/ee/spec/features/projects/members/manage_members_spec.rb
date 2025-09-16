# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Projects > Members > Manage members', :js, feature_category: :groups_and_projects do
  include Features::InviteMembersModalHelpers
  include SubscriptionPortalHelpers

  context 'with free user limit', :saas do
    let_it_be(:group) { create(:group_with_plan, :private, plan: :free_plan) }
    let_it_be(:project) { create(:project, :private, group: group, name: 'free-user-limit-project') }
    let_it_be(:user) { project.creator }

    before_all do
      group.add_owner(user)
    end

    before do
      stub_signing_key
      stub_reconciliation_request(true)
      stub_ee_application_setting(dashboard_limit_enabled: true)
    end

    context 'when at free user limit' do
      it 'shows the alert notification in the modal' do
        stub_ee_application_setting(dashboard_limit: 1)

        sign_in(user)

        visit project_project_members_path(project)

        click_on 'Invite members'

        page.within invite_modal_selector do
          expect(page).to have_content "You've reached your"
          expect(page).to have_content 'To invite new users to this top-level group, you must remove existing users.'
        end
      end
    end

    context 'when close to free user limit on a top-level group' do
      it 'shows the alert notification in the modal',
        quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/461953' do
        stub_ee_application_setting(dashboard_limit: 4)

        sign_in(user)

        visit project_project_members_path(project)

        invite_member(create(:user).name)

        click_on _('Invite members')

        page.within invite_modal_selector do
          expect(page).to have_content 'You only have space for 2'
          expect(page).to have_content 'To get more members an owner of the group can'

          click_on _('Cancel')
        end

        invite_member(create(:user).name)

        click_on _('Invite members')

        page.within invite_modal_selector do
          expect(page).to have_content 'You only have space for 1'
          expect(page).to have_content 'To get more members an owner of the group can'
        end
      end
    end
  end

  context 'with queued users' do
    let_it_be(:group) { create(:group) }
    let_it_be(:user1) { create(:user) }

    it_behaves_like 'queued users' do
      let_it_be(:subentity) { create(:project, namespace: group) }
      let_it_be(:subentity_members_page_path) { project_project_members_path(subentity) }
    end
  end

  context 'with an active trial', :saas do
    let_it_be(:group) { create(:group, :private, name: 'active-trial-group') }
    let_it_be(:project) { create(:project, :private, group: group, name: 'active-trial-project') }
    let_it_be(:user) { project.creator }

    before do
      create(:gitlab_subscription, :active_trial, namespace: group)

      stub_ee_application_setting(dashboard_limit_enabled: true)

      group.add_owner(user)

      sign_in(user)
    end

    it 'shows the active trial unlimited members alert' do
      visit project_project_members_path(project)

      click_on _('Invite members')

      page.within invite_modal_selector do
        expect(page).to have_content 'Add unlimited members with your trial'
        expect(page).to have_content 'During your trial, you can invite as many members to active-trial-project'
        expect(page).to have_link(text: 'upgrade to a paid plan', href: group_billings_path(group.root_ancestor))
        expect(page).to have_content 'Cancel'
      end
    end
  end
end
