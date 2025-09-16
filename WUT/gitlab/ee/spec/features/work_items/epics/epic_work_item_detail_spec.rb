# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Epic work item detail', :js, feature_category: :team_planning do
  include DragTo
  include ListboxHelpers

  let_it_be_with_reload(:user) { create(:user) }
  let_it_be_with_reload(:user2) { create(:user, name: 'John') }

  let_it_be(:group) { create(:group, :nested, developers: user) }
  let_it_be(:label) { create(:group_label, group: group) }
  let_it_be(:label2) { create(:group_label, group: group) }
  let_it_be_with_reload(:work_item) do
    create(:work_item, :epic_with_legacy_epic, :group_level, namespace: group, labels: [label])
  end

  let_it_be(:emoji_upvote) { create(:award_emoji, :upvote, awardable: work_item, user: user2) }
  let(:work_items_path) { group_epic_path(group, work_item.iid) }
  let(:list_path) { group_epics_path(group) }

  context 'for signed in user' do
    let(:child_item) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
    let(:linked_item) { child_item }

    before do
      stub_feature_flags(notifications_todos_buttons: false)
      stub_licensed_features(epic_colors: true, epics: true, issuable_health_status: true, linked_items_epics: true,
        related_epics: true, subepics: true)
      sign_in(user)
      visit work_items_path
    end

    it 'shows breadcrumb links', :aggregate_failures do
      within_testid('breadcrumb-links') do
        expect(page).to have_link(group.name, href: group_path(group))
        expect(page).to have_link('Epics', href: list_path)
        expect(find('nav:last-of-type li:last-of-type')).to have_link(work_item.to_reference,
          href: group_epic_path(group, work_item.iid))
      end
    end

    it_behaves_like 'work items title'
    it_behaves_like 'work items award emoji'
    it_behaves_like 'work items hierarchy', 'work-item-tree', :epic
    it_behaves_like 'work items linked items', true
    it_behaves_like 'work items toggle status button'

    it_behaves_like 'work items todos'
    it_behaves_like 'work items lock discussion', 'epic'
    it_behaves_like 'work items confidentiality'
    it_behaves_like 'work items notifications'

    it_behaves_like 'work items assignees'
    it_behaves_like 'work items labels', 'group'
    it_behaves_like 'work items rolled up dates'
    it_behaves_like 'work items health status'
    it_behaves_like 'work items color'
    it_behaves_like 'work items time tracking'

    describe 'work item hierarchy' do
      let(:child1) { create(:work_item, :epic_with_legacy_epic, namespace: group, title: 'Child 1') }
      let(:child2) { create(:work_item, :epic_with_legacy_epic, namespace: group, title: 'Child 2') }
      let(:child1a) { create(:work_item, :epic_with_legacy_epic, namespace: group, title: 'Child 1a') }

      describe 'nested children' do
        before do
          create(:parent_link, work_item_parent: work_item, work_item: child1)
          create(:parent_link, work_item_parent: work_item, work_item: child2)
          create(:parent_link, work_item_parent: child1, work_item: child1a)
          page.refresh
        end

        it 'can be expanded, removed, and re-added', :aggregate_failures do
          within_testid 'work-item-tree' do
            expect(page).to have_link 'Child 1'
            expect(page).to have_link 'Child 2'
            expect(page).not_to have_link 'Child 1a'

            click_button('Expand', match: :first)

            expect(page).to have_link 'Child 1'
            expect(page).to have_link 'Child 2'
            expect(page).to have_link 'Child 1a'

            # hover over the "Child 1a" link so the first "Remove" button is the one to remove "Child 1a"
            find_link('Child 1a').hover
            click_button 'Remove', match: :first

            expect(page).not_to have_link 'Child 1a'
          end

          within '.gl-toast' do
            expect(page).to have_content(_('Child removed'))

            find('a', text: 'Undo').click # click_link doesn't work here for some reason
          end

          within_testid 'work-item-tree' do
            expect(page).to have_link 'Child 1a'
          end
        end
      end
    end
  end

  context 'without epics license' do
    before do
      stub_licensed_features(epics: false)
      sign_in(user)
      visit work_items_path
    end

    it 'shows 404' do
      expect(page).to have_content 'Page not found'
    end
  end
end
