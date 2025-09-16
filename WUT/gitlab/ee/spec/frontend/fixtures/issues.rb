# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GraphQL::Query, type: :request, feature_category: :team_planning do
  include ApiHelpers
  include GraphqlHelpers
  include JavaScriptFixturesHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, reporters: user) }

  issue_popover_query_path = 'issuable/popover/queries/issue.query.graphql'

  it "ee/graphql/#{issue_popover_query_path}.json" do
    query = get_graphql_query_as_string(issue_popover_query_path, ee: true)

    issue = create(
      :issue,
      project: project,
      confidential: true,
      created_at: Time.parse('2020-07-01T04:08:01Z'),
      due_date: Date.new(2020, 7, 5),
      start_date: Date.new(2020, 7, 3),
      milestone: create(
        :milestone,
        project: project,
        title: '15.2',
        start_date: Date.new(2020, 7, 1),
        due_date: Date.new(2020, 7, 30)
      ),
      weight: 3
    )

    post_graphql(query, current_user: user, variables: { fullPath: project.full_path, iid: issue.iid.to_s })

    expect_graphql_errors_to_be_empty
  end
end
