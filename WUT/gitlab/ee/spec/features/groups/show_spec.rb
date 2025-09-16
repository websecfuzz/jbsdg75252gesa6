# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Group show page', :js, :saas, feature_category: :groups_and_projects do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :private, owners: user) }

  context "with free tier badge" do
    let(:tier_badge_element) { find_by_testid('tier-badge') }
    let(:popover_element) { page.find('.gl-popover') }

    before do
      sign_in(user)
      visit group_path(group)
    end

    it 'renders the tier badge and popover when clicked' do
      expect(tier_badge_element).to be_present

      tier_badge_element.click

      expect(popover_element.text).to include('Enhance team productivity')
      expect(popover_element.text).to include('This group and all its related projects use the Free GitLab tier.')
    end
  end

  context 'with enable duo banner' do
    let_it_be(:gitlab_subscription) { create(:gitlab_subscription, end_date: 1.month.from_now, namespace: group) }
    let_it_be(:duo_core) { create(:gitlab_subscription_add_on_purchase, :duo_core, namespace: group) }

    before do
      stub_licensed_features(ai_features: true)
      sign_in(user)
      visit group_path(group)
    end

    it 'enables the namespace setting `duo_core_features_enabled` when the enable button is pressed' do
      find_button('Enable GitLab Duo Core').click

      wait_for_all_requests

      find_button('Enable').click

      wait_for_all_requests

      expect(group.reload.namespace_settings.duo_core_features_enabled).to be true
    end

    it 'dismisses the banner properly' do
      find_by_testid('enable-duo-banner').find('.gl-banner-close').click

      page.refresh

      wait_for_all_requests

      expect(page).not_to have_css('[data-testid="enable-duo-banner"]')
    end
  end
end
