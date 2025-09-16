# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "querying merge requests", feature_category: :code_review_workflow do
  include GraphqlHelpers
  include MrResolverHelpers

  describe 'querying merge requests with a possible approver' do
    let_it_be(:project) { create(:project, :repository) }
    let_it_be(:other_user) { create(:user) }
    let_it_be(:current_user) { create(:user) }
    let_it_be(:common_attrs) { { author: current_user, source_project: project, target_project: project } }
    let_it_be(:merge_request) { create(:merge_request, :unique_branches, **common_attrs) }
    let_it_be(:other_merge_request) { create(:merge_request, :unique_branches, **common_attrs) }
    let_it_be(:username) { other_user.username }
    let(:query) do
      %(
        {
          project(fullPath: "#{project.full_path}") {
            mergeRequests(approver: "#{username}") {
              nodes {
                title } } } }
      )
    end

    before_all do
      project.add_developer(current_user)
      project.add_developer(other_user)
      merge_request.approvers.create!(user: other_user)
    end

    context 'with valid approver argument' do
      subject(:results) { GitlabSchema.execute(query, context: { current_user: current_user }) }

      it 'filters merge requests by reviewers state' do
        mrs = results.dig('data', 'project', 'mergeRequests', 'nodes')

        expect(mrs.first['title']).to eq(merge_request.title)
      end

      it 'handles n+1 situations' do
        control = ActiveRecord::QueryRecorder.new { results }

        merge_request.approvers.create!(user: other_user)

        expectation = expect { results }

        expectation.not_to exceed_query_limit(control)
      end
    end

    context 'with an invalid approver' do
      subject(:results) { GitlabSchema.execute(query, context: { current_user: current_user }) }

      let(:username) { "awesome_user_123" }

      it 'does not find anything' do
        mrs = results.dig('data', 'project', 'mergeRequests', 'nodes')

        expect(mrs).to be_empty
      end
    end
  end
end
