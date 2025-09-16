# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Groups > Usage Quotas > Storage tab', :js, :saas, feature_category: :consumables_cost_management do
  include NamespaceStorageHelpers
  include SubscriptionPortalHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group_with_plan, plan: :premium_plan, owners: user) }
  let_it_be(:root_storage_statistics, refind: true) do
    create(:namespace_root_storage_statistics, namespace: group,
      storage_size: 300.megabytes, public_forks_storage_size: 100.megabytes)
  end

  before do
    stub_signing_key
    stub_subscription_permissions_data(group.id)

    stub_application_setting(check_namespace_plan: true)
    create(:callout, user: user, feature_name: :duo_chat_callout, dismissed_at: Time.current)

    sign_in(user)
  end

  context 'with pagination' do
    let(:per_page) { 1 }
    let(:item_selector) { '.js-project-link' }
    let(:prev_button_selector) { '[data-testid="prevButton"]' }
    let(:next_button_selector) { '[data-testid="nextButton"]' }
    let!(:projects) { create_list(:project, 3, namespace: group) }

    before do
      allow(Kaminari.config).to receive(:default_per_page).and_return(per_page)
      visit_usage_quotas_page('storage-quota-tab')
    end

    it_behaves_like 'correct pagination'
  end

  context 'with namespace storage limit' do
    let_it_be(:project) { create(:project, namespace: group) }

    before do
      enforce_namespace_storage_limit(group)
      set_enforcement_limit(group, megabytes: 100)
    end

    context 'when over storage limit' do
      before do
        set_used_storage(group, megabytes: 105)
      end

      it 'still displays the project under the group' do
        visit_usage_quotas_page('storage-quota-tab')

        expect(page).to have_text(project.name)
      end
    end

    context 'with a fork of a project' do
      let_it_be(:project_fork) { create(:project, namespace: group) }
      let_it_be(:statistics) { create(:project_statistics, project: project_fork, repository_size: 100.megabytes) }
      let_it_be(:fork_network) { create(:fork_network, root_project: project) }
      let_it_be(:fork_network_member) do
        create(:fork_network_member, project: project_fork,
          fork_network: fork_network, forked_from_project: project)
      end

      context 'with a cost factor for forks' do
        before do
          stub_ee_application_setting(namespace_storage_forks_cost_factor: 0.1)
        end

        it 'displays the storage size with the cost factor applied' do
          visit_usage_quotas_page('storage-quota-tab')

          expect(page).to have_css('td[data-label="Total"]', text: "10.0 MiB")
          expect(page).to have_css('td[data-label="Total"]', text: "(of 100.0 MiB)")
        end
      end

      context 'without a cost factor for forks' do
        it 'does not display the forked storage size' do
          visit_usage_quotas_page('storage-quota-tab')

          expect(page).to have_css('td[data-label="Total"]', text: '100.0 MiB')
          expect(page).not_to have_text('of 100.0 MiB')
        end
      end
    end
  end

  context 'with a cost factor for forks' do
    before do
      stub_ee_application_setting(namespace_storage_forks_cost_factor: 0.1)
    end

    it 'displays the total storage size taking into account the cost factor' do
      visit_usage_quotas_page('storage-quota-tab')

      # A cost factor for forks of 0.1 means that forks consume only 10% of their storage size.
      # So this is the total storage_size (300 MB) - 90% of the public_forks_storage_size (90 MB).
      expect(page).to have_text('Namespace storage used 210.0 MiB')
    end
  end

  context 'when user has limited access to subscription' do
    before do
      stub_subscription_permissions_data(group.id, can_add_seats: false)
      enforce_namespace_storage_limit(group)
      set_enforcement_limit(group, megabytes: 100)

      visit_usage_quotas_page('storage-quota-tab')
      wait_for_requests

      click_button 'Buy storage'
    end

    context 'when user is not allowed to add storage' do
      it 'opens limited access modal' do
        expect(page).to have_selector('[data-testid="limited-access-modal-id"]')
        expect(page).to have_content('Your subscription is in read-only mode')
      end
    end
  end

  def visit_usage_quotas_page(anchor = 'seats-quota-tab')
    visit group_usage_quotas_path(group, anchor: anchor)
  end
end
