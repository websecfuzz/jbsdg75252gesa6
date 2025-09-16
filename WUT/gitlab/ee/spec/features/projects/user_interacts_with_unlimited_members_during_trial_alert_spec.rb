# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Project > Unlimited members alert', :js, :saas, feature_category: :groups_and_projects do
  include SubscriptionPortalHelpers

  let(:alert_selector) { '[data-testid="unlimited-members-during-trial-alert"]' }
  let_it_be(:group) { create(:group, :private, name: 'unlimited-members-during-trial-alert-group') }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user) }

  before do
    stub_get_billing_account_details

    stub_feature_flags(streamlined_first_product_experience: false)
  end

  context 'when group not in trial' do
    it 'does not display alert' do
      group.add_owner(user)
      project.add_owner(user)

      sign_in(user)

      visit project_path(project)

      expect_on_project_index_without_alert
    end
  end

  context 'when group is in trial' do
    before do
      create(:gitlab_subscription, :active_trial, namespace: group)

      stub_application_setting(dashboard_limit_enabled: true)
    end

    context 'when user is not owner' do
      it 'does not display alert' do
        group.add_maintainer(user)
        project.add_maintainer(user)
        sign_in(user)

        visit project_path(project)

        expect_on_project_index_without_alert
      end
    end

    context 'when user is owner' do
      before do
        group.add_owner(user)
        project.add_owner(user)

        sign_in(user)

        stub_temporary_extension_data(group.id)
      end

      it_behaves_like 'unlimited members during trial alert' do
        let_it_be(:members_page_path) { project_project_members_path(project) }
        let_it_be(:billings_page_path) { group_billings_path(group) }
        let_it_be(:page_path) { project_path(project) }
        let_it_be(:current_page_label) { project.name }
      end
    end
  end

  def expect_on_project_index_without_alert
    expect(page).to have_selector('a[aria-current="page"]', text: project.name)
    expect(page).not_to have_selector(alert_selector)
  end
end
