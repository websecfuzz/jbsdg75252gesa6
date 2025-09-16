# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Merge Requests > User filters', :js, feature_category: :code_review_workflow do
  include FilteredSearchHelpers

  let_it_be(:project) { create(:project, :public, :repository) }
  let_it_be(:user)    { project.creator }
  let_it_be(:group_user) { create(:user) }
  let_it_be(:first_user) { create(:user) }

  let_it_be(:merge_request_with_approver) do
    create(:merge_request, approval_users: [first_user], title: 'Bugfix1', source_project: project, source_branch: 'bugfix1')
  end

  let_it_be(:merge_request_with_two_approvers) do
    create(:merge_request, title: 'Bugfix2', approval_users: [user, first_user], source_project: project, source_branch: 'bugfix2')
  end

  let_it_be(:merge_request) { create(:merge_request, title: 'Bugfix3', source_project: project, source_branch: 'bugfix3') }
  let_it_be(:merge_request_with_group_approver) do
    group = create(:group)
    group.add_developer(group_user)

    create(:merge_request, approval_groups: [group], title: 'Bugfix4', source_project: project, source_branch: 'bugfix4')
  end

  before_all do
    project.add_developer(first_user)
    project.add_developer(group_user)
  end

  before do
    sign_in(user)
    visit project_merge_requests_path(project)
  end

  context 'by "approvers"' do
    context 'filtering by approver:none' do
      it 'applies the filter' do
        select_tokens 'Approver', 'None', submit: true

        expect(page).to have_issuable_counts(open: 1, closed: 0, all: 1)

        expect(page).not_to have_content 'Bugfix1'
        expect(page).not_to have_content 'Bugfix2'
        expect(page).not_to have_content 'Bugfix4'
        expect(page).to have_content 'Bugfix3'
      end
    end

    context 'filtering by approver:any' do
      it 'applies the filter' do
        select_tokens 'Approver', 'Any', submit: true

        expect(page).to have_issuable_counts(open: 3, closed: 0, all: 3)

        expect(page).to have_content 'Bugfix1'
        expect(page).to have_content 'Bugfix2'
        expect(page).to have_content 'Bugfix4'
        expect(page).not_to have_content 'Bugfix3'
      end
    end

    context 'filtering by approver:@username' do
      it 'applies the filter' do
        select_tokens 'Approver', first_user.username, submit: true

        expect(page).to have_issuable_counts(open: 2, closed: 0, all: 2)

        expect(page).to have_content 'Bugfix1'
        expect(page).to have_content 'Bugfix2'
        expect(page).not_to have_content 'Bugfix3'
        expect(page).not_to have_content 'Bugfix4'
      end
    end

    context 'filtering by multiple approvers' do
      it 'applies the filter' do
        select_tokens 'Approver', first_user.username, 'Approver', user.username, submit: true

        expect(page).to have_issuable_counts(open: 1, closed: 0, all: 1)

        expect(page).to have_content 'Bugfix2'
        expect(page).not_to have_content 'Bugfix1'
        expect(page).not_to have_content 'Bugfix3'
        expect(page).not_to have_content 'Bugfix4'
      end
    end

    context 'filtering by an approver from a group' do
      it 'applies the filter' do
        select_tokens 'Approver', group_user.username, submit: true

        expect(page).to have_issuable_counts(open: 1, closed: 0, all: 1)

        expect(page).to have_content 'Bugfix4'
        expect(page).not_to have_content 'Bugfix1'
        expect(page).not_to have_content 'Bugfix2'
        expect(page).not_to have_content 'Bugfix3'
      end
    end
  end
end
