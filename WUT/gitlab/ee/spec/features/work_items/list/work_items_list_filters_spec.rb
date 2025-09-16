# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Work items list filters', :js, feature_category: :team_planning do
  include FilteredSearchHelpers

  let_it_be(:user) { create(:user) }

  let_it_be(:group) { create(:group) }
  let_it_be(:sub_group) { create(:group, parent: group) }
  let_it_be(:sub_group_project) { create(:project, :public, group: sub_group, developers: user) }
  let_it_be(:sub_sub_group) { create(:group, parent: sub_group) }
  let_it_be(:project) { create(:project, :public, group: group, developers: user) }

  let_it_be(:epic) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
  let_it_be(:sub_epic) { create(:work_item, :epic_with_legacy_epic, namespace: sub_group) }
  let_it_be(:sub_issue) { create(:issue, project: sub_group_project) }
  let_it_be(:sub_sub_epic) { create(:work_item, :epic_with_legacy_epic, namespace: sub_sub_group) }

  let_it_be(:incident) { create(:incident, project: project) }
  let_it_be(:issue) { create(:issue, project: project) }
  let_it_be(:task) { create(:work_item, :task, project: project) }
  let_it_be(:test_case) { create(:quality_test_case, project: project) }

  context 'for signed in user' do
    before do
      stub_licensed_features(epics: true, quality_management: true, subepics: true)
      sign_in(user)
      visit group_work_items_path(group)
    end

    describe 'group' do
      it 'filters', :aggregate_failures, quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/523412' do
        select_tokens 'Group', group.name, submit: true

        expect(page).to have_css('.issue', count: 1)
        expect(page).to have_link(epic.title)

        click_button 'Clear'

        select_tokens 'Group', sub_group.name, submit: true

        expect(page).to have_css('.issue', count: 1)
        expect(page).to have_link(sub_epic.title)

        click_button 'Clear'

        select_tokens 'Group', sub_sub_group.name, submit: true

        expect(page).to have_css('.issue', count: 1)
        expect(page).to have_link(sub_sub_epic.title)
      end
    end

    describe 'type' do
      it 'filters', :aggregate_failures do
        select_tokens('Type', '=', 'Issue', submit: true)

        expect(page).to have_css('.issue', count: 2)
        expect(page).to have_link(issue.title)
        expect(page).to have_link(sub_issue.title)

        click_button 'Clear'

        select_tokens('Type', '=', 'Inciden', submit: true)

        expect(page).to have_css('.issue', count: 1)
        expect(page).to have_link(incident.title)

        click_button 'Clear'

        select_tokens('Type', '=', 'Test case', submit: true)

        expect(page).to have_css('.issue', count: 1)
        expect(page).to have_link(test_case.title)

        click_button 'Clear'

        select_tokens('Type', '=', 'Task', submit: true)

        expect(page).to have_css('.issue', count: 1)
        expect(page).to have_link(task.title)
      end
    end
  end
end
