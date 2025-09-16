# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Blocking issues count', feature_category: :team_planning do
  include Features::SortingHelpers

  let_it_be(:project) { build(:project, :public) }
  let_it_be(:blocked_issue) { build(:issue, project: project, created_at: 1.day.ago) }
  let_it_be(:issue1) { build(:issue, project: project, created_at: 2.days.ago, title: 'blocks one issue') }
  let_it_be(:issue2) { build(:issue, project: project, created_at: 3.days.ago, title: 'blocks two issues') }

  before do
    # TODO: When removing the feature flag,
    # we won't need the tests for the issues listing page, since we'll be using
    # the work items listing page.
    stub_feature_flags(work_item_planning_view: false)

    visit project_issues_path(project)
  end

  before_all do
    create(:issue_link, source: issue1, target: blocked_issue, link_type: IssueLink::TYPE_BLOCKS)
    create(:issue_link, source: issue2, target: issue1, link_type: IssueLink::TYPE_BLOCKS)
    create(:issue_link, source: issue2, target: blocked_issue, link_type: IssueLink::TYPE_BLOCKS)
  end

  it 'sorts by blocking', :js do
    pajamas_sort_by 'Blocking', from: 'Created date'

    page.within(".issues-list") do
      page.within("li.issue:nth-child(1)") do
        expect(page).to have_content('blocks two issues')
        expect(find_by_testid('blocking-issues')).to have_content('2')
      end

      page.within("li.issue:nth-child(2)") do
        expect(page).to have_content('blocks one issue')
        expect(find_by_testid('blocking-issues')).to have_content('1')
      end
    end
  end
end
