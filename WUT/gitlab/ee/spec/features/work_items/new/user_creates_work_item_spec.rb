# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User creates work items', :js, feature_category: :team_planning do
  include Spec::Support::Helpers::ModalHelpers
  include ListboxHelpers
  include WorkItemsHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :public, developers: user) }
  let_it_be(:project) { create(:project, :public, developers: user, group: group) }

  before do
    sign_in(user)
  end

  context 'when on new project work items page' do
    before do
      stub_licensed_features(issuable_health_status: true, iterations: true)
      visit "#{project_path(project)}/-/work_items/new"
    end

    it_behaves_like 'creates work item with widgets from new page', 'issue', %w[
      work-item-iteration
      work-item-weight
      work-item-health-status
    ]
  end

  context 'when on new group work items list page' do
    let_it_be(:label) { create(:group_label, title: 'Label 1', group: group) }
    let_it_be(:milestone) { create(:milestone, group: group, title: 'Milestone') }
    let(:issuable_container) { '[data-testid="issuable-container"]' }

    before do
      stub_licensed_features(epics: true, epic_colors: true, issuable_health_status: true, subepics: true)
      visit group_work_items_path(group)
      wait_for_all_requests
      click_link 'New item'
    end

    it_behaves_like 'creates work item with widgets from a modal', 'epic', %w[
      work-item-description-wrapper
      work-item-assignees
      work-item-health-status
      work-item-labels
      work-item-due-dates
      work-item-color
      work-item-parent
    ]

    it 'renders metadata as set during work item creation' do
      allow(Gitlab::QueryLimiting::Transaction).to receive(:threshold).and_return(125)

      select_work_item_type('Epic')

      fill_work_item_title('Epic with metadata')

      assign_work_item_to_yourself

      set_work_item_label(label.title)

      set_work_item_milestone(milestone.title)

      create_work_item_with_type('epic')

      wait_for_all_requests

      within(all(issuable_container)[0]) do
        expect(page).to have_link(milestone.title)
          .and have_link(label.name)
          .and have_link(user.name, href: user_path(user))
      end
    end
  end

  context 'when on group epics page' do
    let_it_be(:parent_epic) { create(:work_item, :epic_with_legacy_epic, namespace: group) }

    before do
      stub_licensed_features(epics: true, epic_colors: true, issuable_health_status: true, subepics: true)
      stub_feature_flags(work_item_planning_view: false)
      visit group_epics_path(group)

      allow(Gitlab::QueryLimiting::Transaction).to receive(:threshold).and_return(120)
    end

    context 'when creating an epic' do
      before do
        click_link 'New epic'
      end

      it 'creates an epic work item with all EE widgets and quick actions', :aggregate_failures do
        within_modal do
          # check all the epic widgets are rendered
          expect(page).to have_selector('[data-testid="work-item-description-wrapper"]')
          expect(page).to have_selector('[data-testid="work-item-assignees"]')
          expect(page).to have_selector('[data-testid="work-item-labels"]')
          expect(page).to have_selector('[data-testid="work-item-due-dates"]')
          expect(page).to have_selector('[data-testid="work-item-health-status"]')
          expect(page).to have_selector('[data-testid="work-item-color"]')
          expect(page).to have_selector('[data-testid="work-item-parent"]')

          send_keys 'I am a new epic'
          fill_in _('Description'), with: "/set_parent #{parent_epic.to_reference}"

          click_button 'Create epic'
          page.refresh
        end

        expect(page).to have_link 'I am a new epic'
        expect(page).to have_css '[data-testid="epic-icon"]'

        click_link('I am a new epic')

        wait_for_requests

        within_testid 'work-item-parent' do
          expect(page).to have_link(parent_epic.title)
        end
      end
    end
  end
end
