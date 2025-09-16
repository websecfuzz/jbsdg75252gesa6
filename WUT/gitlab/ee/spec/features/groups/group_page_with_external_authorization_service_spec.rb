# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'The group page', :js, feature_category: :groups_and_projects do
  include ExternalAuthorizationServiceHelpers

  let(:user) { create(:user) }
  let(:group) { create(:group) }

  before do
    sign_in user
    group.add_owner(user)
  end

  describe 'The sidebar' do
    it 'shows the link to contribution analytics' do
      visit group_path(group)

      within_testid('super-sidebar') do
        click_button 'Analyze'
        expect(page).to have_link('Contribution analytics')
      end
    end

    context 'when epics are available' do
      before do
        stub_licensed_features(epics: true)
      end

      it 'shows the link to work items' do
        visit group_path(group)

        within_testid('super-sidebar') do
          expect(page).to have_link('Work items')
        end
      end

      it 'hides the work items link when an external authorization service is enabled' do
        enable_external_authorization_service_check
        visit group_path(group)

        within_testid('super-sidebar') do
          expect(page).not_to have_link('Work items')
        end
      end

      context 'and work_item_planning_view feature flag is disabled' do
        before do
          stub_feature_flags(work_item_planning_view: false)
        end

        it 'shows the link to epics' do
          visit group_path(group)

          within_testid('super-sidebar') do
            expect(page).to have_link('Epics')
          end
        end

        it 'hides the epics link when an external authorization service is enabled' do
          enable_external_authorization_service_check
          visit group_path(group)

          within_testid('super-sidebar') do
            expect(page).not_to have_link('Epics')
          end
        end
      end
    end
  end
end
