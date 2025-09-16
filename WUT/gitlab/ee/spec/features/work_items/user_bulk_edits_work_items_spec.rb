# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Work items bulk editing', :js, feature_category: :team_planning do
  include ListboxHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:bug_label) { create(:group_label, group: group, title: 'bug') }
  let_it_be(:feature_label) { create(:group_label, group: group, title: 'feature') }
  let_it_be(:frontend_label) { create(:group_label, group: group, title: 'frontend') }
  let_it_be(:wontfix_label) { create(:group_label, group: group, title: 'wontfix') }
  let_it_be(:epic) { create(:work_item, :epic, namespace: group, title: "Epic without label") }
  let_it_be(:issue) { create(:work_item, :issue, project: project, title: "Issue without label") }
  let_it_be(:epic_with_label) do
    create(:work_item, :epic, namespace: group, title: "Epic with label", labels: [frontend_label])
  end

  let_it_be(:epic_with_multiple_labels) do
    create(:work_item, :epic, namespace: group, title: "Epic with multiple labels",
      labels: [frontend_label, wontfix_label, feature_label])
  end

  before_all do
    group.add_developer(user)
  end

  before do
    sign_in user
    stub_licensed_features(epics: true, group_bulk_edit: true)
  end

  context 'when user is signed in' do
    context 'when bulk editing labels' do
      before do
        visit_work_items_page
        click_bulk_edit
      end

      context 'when user bulk assigns labels' do
        it 'assigns single label on an epic' do
          select_item(epic)
          add_labels([feature_label.title])
          update_selected

          expect(work_item_element(epic)).to have_content 'feature'
        end

        it 'assigns labels on multiple epics' do
          select_item(epic)
          select_item(epic_with_label)
          add_labels([wontfix_label.title])

          update_selected

          aggregate_failures do
            expect(work_item_element(epic)).to have_content 'wontfix'
            expect(work_item_element(epic_with_label)).to have_content 'wontfix'
            expect(work_item_element(epic_with_label)).to have_content 'frontend'
          end
        end

        it 'assigns multiple labels on one epic' do
          select_item(epic)
          add_labels([wontfix_label.title, frontend_label.title])

          update_selected

          aggregate_failures do
            expect(work_item_element(epic)).to have_content 'frontend'
            expect(work_item_element(epic)).to have_content 'wontfix'
          end
        end

        it 'assigns labels on mixed work item types' do
          select_item(epic)
          select_item(issue)
          add_labels([feature_label.title, wontfix_label.title])

          update_selected

          aggregate_failures do
            expect(work_item_element(issue)).to have_content 'wontfix'
            expect(work_item_element(issue)).to have_content 'feature'
            expect(work_item_element(epic)).to have_content 'wontfix'
            expect(work_item_element(epic)).to have_content 'feature'
          end
        end
      end

      context 'when user bulk unassigns labels' do
        it 'unassigns single label from one epic' do
          select_item(epic_with_multiple_labels)
          remove_labels([wontfix_label.title])
          dismiss_dropdown_overlay

          update_selected

          aggregate_failures do
            expect(work_item_element(epic_with_multiple_labels)).not_to have_content 'wontfix'
            expect(work_item_element(epic_with_multiple_labels)).to have_content 'frontend'
            expect(work_item_element(epic_with_multiple_labels)).to have_content 'feature'
          end
        end

        it 'unassigns multiple labels from one epic' do
          select_item(epic_with_multiple_labels)
          remove_labels([wontfix_label.title, frontend_label.title])
          dismiss_dropdown_overlay

          update_selected

          aggregate_failures do
            expect(work_item_element(epic_with_multiple_labels)).not_to have_content 'wontfix'
            expect(work_item_element(epic_with_multiple_labels)).not_to have_content 'frontend'
            expect(work_item_element(epic_with_multiple_labels)).to have_content 'feature'
          end
        end

        it 'unassigns labels from multiple epics' do
          select_item(epic_with_label)
          select_item(epic_with_multiple_labels)
          remove_labels([feature_label.title, frontend_label.title])
          dismiss_dropdown_overlay

          update_selected

          aggregate_failures do
            expect(work_item_element(epic_with_label)).not_to have_content 'frontend'
            expect(work_item_element(epic_with_multiple_labels)).not_to have_content 'feature'
            expect(work_item_element(epic_with_multiple_labels)).not_to have_content 'frontend'
            expect(work_item_element(epic_with_multiple_labels)).to have_content 'wontfix'
          end
        end
      end

      context 'when user bulk assigns and unassigns labels simultaneously' do
        it 'processes both operations correctly' do
          select_item(epic)
          select_item(epic_with_label)
          add_labels([feature_label.title, wontfix_label.title])
          dismiss_dropdown_overlay

          remove_labels([frontend_label.title])
          dismiss_dropdown_overlay

          update_selected

          aggregate_failures do
            expect(work_item_element(epic_with_label)).not_to have_content 'frontend'
            expect(work_item_element(epic)).not_to have_content 'frontend'
            expect(work_item_element(epic)).to have_content 'wontfix'
            expect(work_item_element(epic)).to have_content 'feature'
            expect(work_item_element(epic_with_label)).to have_content 'wontfix'
            expect(work_item_element(epic_with_label)).to have_content 'feature'
          end
        end
      end
    end
  end

  private

  def add_labels(items = [])
    select_labels_from_dropdown('bulk-edit-add-labels', items)
  end

  def remove_labels(items = [])
    select_labels_from_dropdown('bulk-edit-remove-labels', items)
  end

  def select_labels_from_dropdown(testid, items)
    within('aside.issues-bulk-update') do
      within_testid(testid) do
        click_button 'Select labels'
        wait_for_requests

        items.each do |item|
          check_item_from_dropdown(item)
        end
      end
    end
  end

  def select_item(item)
    check item.title
  end

  def check_item_from_dropdown(item)
    select_listbox_item item
  end

  def visit_work_items_page
    visit group_work_items_path(group)
    wait_for_requests
  end

  def click_bulk_edit
    click_button 'Bulk edit'
  end

  def update_selected
    click_button 'Update selected'
    wait_for_requests
  end

  def work_item_element(work_item)
    find("#issuable_#{work_item.id}")
  end

  def dismiss_dropdown_overlay
    # The listbox is hiding UI elements, click body to dismiss
    page.find('body').click
  end
end
