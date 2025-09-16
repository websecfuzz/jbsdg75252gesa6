# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Filter issues by multiple assignees', :js, feature_category: :team_planning do
  include FilteredSearchHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:user2) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:issue1) { create(:issue, project: project, author: user, assignees: [user, user2]) }
  let_it_be(:issue2) { create(:issue, project: project, assignees: [user]) }

  before_all do
    project.add_maintainer(user)
    project.add_developer(user2)
  end

  before do
    # TODO: When removing the feature flag,
    # we won't need the tests for the issues listing page, since we'll be using
    # the work items listing page.
    stub_feature_flags(work_item_planning_view: false)

    sign_in(user)
    visit project_issues_path(project)
  end

  describe 'with AND filtering' do
    it 'filters issues by multiple assignees' do
      select_tokens 'Assignee', '=', user.username, 'Assignee', '=', user2.username, submit: true

      expect_assignee_token(user.name)
      expect_assignee_token(user2.name)
      expect_issues_list_count(1)
      expect_empty_search_term
    end
  end

  describe 'with OR filtering' do
    it 'filters issues by multiple assignees' do
      select_tokens 'Assignee', '||', user.username, user2.username, submit: true

      expect_unioned_assignee_token("#{user.name}, #{user2.name}")
      expect_issues_list_count(2)
      expect_empty_search_term
    end
  end
end
