# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'OKR', :js, feature_category: :portfolio_management do
  include DragTo
  include ListboxHelpers

  let_it_be(:organization) { create(:organization) }
  let(:user) { create(:user, name: 'Sherlock Holmes') }
  let(:user2) { create(:user, name: 'John') }
  let(:group) { create(:group, :public, organization: organization) }
  let(:project) { create(:project, :public, namespace: group) }
  let(:label) { create(:label, project: project, title: "testing-label") }
  let(:label2) { create(:label, project: project, title: "another-label") }
  let(:objective) { create(:work_item, :objective, project: project, labels: [label]) }
  let!(:emoji_upvote) { create(:award_emoji, :upvote, awardable: objective, user: user2) }
  let(:key_result) { create(:work_item, :key_result, project: project, labels: [label]) }
  let(:child_item) { create(:work_item, :objective, project: project) }
  let(:list_path) { project_issues_path(project) }

  before do
    group.add_developer(user)

    sign_in(user)

    stub_licensed_features(okrs: true, issuable_health_status: true)
    stub_feature_flags(work_items: true, okrs_mvc: true)

    # TODO: When removing the feature flag,
    # we won't need the tests for the issues listing page, since we'll be using
    # the work items listing page.
    stub_feature_flags(work_item_planning_view: false)
  end

  describe 'creating objective from issues list' do
    before do
      visit project_issues_path(project)
    end

    it 'creates an objective from the "New item" toggle button' do
      click_link 'New item'
      select 'Objective', from: 'Type'
      fill_in 'Title', with: 'I object!'
      click_button 'Create objective'

      expect(page).to have_link 'I object!'
    end
  end

  context 'for objective' do
    let(:work_item) { objective }
    let(:work_items_path) { project_work_item_path(project, objective.iid) }

    before do
      visit work_items_path
    end

    it_behaves_like 'work items title'
    it_behaves_like 'work items description'
    it_behaves_like 'work items award emoji'
    it_behaves_like 'work items hierarchy', 'work-item-tree', :objective
    it_behaves_like 'work items comments', :objective
    it_behaves_like 'work items toggle status button'

    it_behaves_like 'work items todos'

    it_behaves_like 'work items assignees'
    it_behaves_like 'work items labels', 'project'
    it_behaves_like 'work items progress'
    it_behaves_like 'work items health status'
    it_behaves_like 'work items parent', :objective

    describe 'work items hierarchy' do
      it 'toggles forms', :aggregate_failures do
        within_testid('work-item-tree') do
          expect(page).not_to have_selector('[data-testid="add-tree-form"]')

          click_button 'Add'
          click_button 'New objective'

          expect(page).to have_selector('[data-testid="add-tree-form"]')
          expect(find_by_testid('add-tree-form')).to have_button('Create objective', disabled: true)

          click_button 'Add'
          click_button 'Existing objective'

          expect(find_by_testid('add-tree-form')).to have_button('Add objective', disabled: true)

          click_button 'Add'
          click_button 'New key result'

          expect(find_by_testid('add-tree-form')).to have_button('Create key result', disabled: true)

          click_button 'Add'
          click_button 'Existing key result'

          expect(find_by_testid('add-tree-form')).to have_button('Add key result', disabled: true)

          click_button 'Cancel'

          expect(page).not_to have_selector('[data-testid="add-tree-form"]')
        end
      end

      context 'in child metadata' do
        it 'displays progress of 0% by default, in tree and modal' do
          # https://gitlab.com/gitlab-org/gitlab/-/issues/467207
          allow(Gitlab::QueryLimiting::Transaction).to receive(:threshold).and_return(300)

          create_okr('objective', 'Objective 2')

          within_testid('work-item-tree') do
            expect(page).to have_content('Objective 2')
            expect(page).to have_content('0%')

            click_link 'Objective 2'
          end

          wait_for_all_requests

          within_testid('work-item-drawer') do
            expect(page).to have_content('0%')
          end
        end
      end

      it 'removes indirect child of objective with undoing',
        quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/466192' do
        # https://gitlab.com/gitlab-org/gitlab/-/issues/467207
        allow(Gitlab::QueryLimiting::Transaction).to receive(:threshold).and_return(300)

        create_okr('objective', 'Objective 2')

        within_testid('work-item-tree') do
          click_link 'Objective 2'

          wait_for_all_requests
        end

        within_testid('work-item-drawer') do
          create_okr('objective', 'Child objective 1')
          expect(page).to have_content('Child objective 1')

          find_by_testid('close-icon', match: :first).click
        end

        visit work_items_path
        wait_for_all_requests

        within_testid('work-item-tree') do
          within_testid('crud-body') do
            click_button 'Expand'

            wait_for_all_requests

            expect(page).to have_content('Child objective 1')
          end
        end

        within_testid('child-items-container', match: :first) do
          find_by_testid('links-child', match: :first).hover
          find_by_testid('remove-work-item-link', match: :first).click

          wait_for_all_requests

          expect(page).not_to have_content('Child objective 1')
        end

        page.within('.gl-toast') do
          expect(find('.toast-body')).to have_content(_('Child removed'))
          find('.b-toaster a', text: 'Undo').click
        end

        wait_for_all_requests

        within_testid('work-item-tree') do
          expect(page).to have_content('Child objective 1')
        end
      end

      it 'creates key result' do
        # https://gitlab.com/gitlab-org/gitlab/-/issues/467207
        allow(Gitlab::QueryLimiting::Transaction).to receive(:threshold).and_return(300)

        create_okr('key result', 'KR 2')

        expect(find_by_testid('work-item-tree')).to have_content('KR 2')
      end
    end
  end

  context 'for keyresult' do
    let(:work_item) { key_result }
    let(:work_items_path) { project_work_item_path(project, key_result.iid) }

    before do
      visit work_items_path
    end

    it_behaves_like 'work items toggle status button'
    it_behaves_like 'work items assignees'
    it_behaves_like 'work items labels', 'project'
    it_behaves_like 'work items progress'
    it_behaves_like 'work items health status'
    it_behaves_like 'work items comments', :key_result
    it_behaves_like 'work items description'
    it_behaves_like 'work items parent', :objective
  end

  context 'for guest users' do
    before do
      project.add_guest(user)

      sign_in(user)

      stub_licensed_features(okrs: true, issuable_health_status: true)
      stub_feature_flags(work_items: true, okrs_mvc: true)

      visit project_work_item_path(project, objective.iid)
    end

    it_behaves_like 'work items todos'
  end

  def create_okr(type, title)
    wait_for_all_requests

    within_testid('work-item-tree') do
      click_button 'Add'
      click_button "New #{type}"
      wait_for_all_requests # wait for work items type to load

      fill_in 'Add a title', with: title

      click_button "Create #{type}"

      wait_for_all_requests
    end
  end
end
