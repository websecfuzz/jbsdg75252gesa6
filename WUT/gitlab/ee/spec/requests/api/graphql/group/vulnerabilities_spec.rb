# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Vulnerabilities through GroupQuery', feature_category: :vulnerability_management do
  include GraphqlHelpers

  describe 'Querying vulnerabilities with `archivalInformation` field' do
    let_it_be(:current_user) { create(:user) }
    let_it_be(:top_level_group) { create(:group) }
    let_it_be(:sub_group_1) { create(:group, parent: top_level_group) }
    let_it_be(:sub_group_2) { create(:group, parent: top_level_group) }

    let_it_be(:project_1) { create(:project, :public, group: top_level_group) }
    let_it_be(:project_2) { create(:project, :public, group: sub_group_1) }
    let_it_be(:project_3) { create(:project, :public, group: sub_group_2) }

    let!(:vulnerability_1) { create(:vulnerability, :with_read, project: project_1) }
    let!(:vulnerability_2) { create(:vulnerability, :with_read, project: project_2, updated_at: 14.months.ago) }
    let!(:vulnerability_3) { create(:vulnerability, :with_read, project: project_3) }

    let(:vulnerabilities_returned) { graphql_data.dig('group', 'vulnerabilities', 'nodes') }

    let(:fields) do
      <<~QUERY
        nodes {
          id
          archivalInformation {
            aboutToBeArchived
            expectedToBeArchivedOn
          }
        }
      QUERY
    end

    let(:query) do
      graphql_query_for(
        :group,
        { full_path: top_level_group.full_path },
        query_graphql_field(:vulnerabilities, fields)
      )
    end

    def execute_graphql_query
      post_graphql(query, current_user: current_user)
    end

    before do
      stub_licensed_features(security_dashboard: true)

      stub_feature_flags(vulnerability_archival: true)
    end

    context 'when the user is not member of the group' do
      it 'does not return any data' do
        execute_graphql_query

        expect(vulnerabilities_returned).to be_empty
      end
    end

    context 'when the user is a member of the group' do
      before_all do
        top_level_group.add_maintainer(current_user)
      end

      around do |example|
        travel_to('2025-04-02') { example.run }
      end

      it 'returns the `aboutToBeArchived` information' do
        execute_graphql_query

        expect(vulnerabilities_returned).to match_array([
          {
            'id' => vulnerability_1.to_global_id.to_s,
            'archivalInformation' => { 'aboutToBeArchived' => false, 'expectedToBeArchivedOn' => '2026-05-01' }
          },
          {
            'id' => vulnerability_2.to_global_id.to_s,
            'archivalInformation' => { 'aboutToBeArchived' => true, 'expectedToBeArchivedOn' => '2025-05-01' }
          },
          {
            'id' => vulnerability_3.to_global_id.to_s,
            'archivalInformation' => { 'aboutToBeArchived' => false, 'expectedToBeArchivedOn' => '2026-05-01' }
          }
        ])
      end

      it 'does not cause N+1 query issue' do
        execute_graphql_query

        queries_recorded = ActiveRecord::QueryRecorder.new(skip_cached: false) { execute_graphql_query }

        new_project = create(:project, group: sub_group_2)
        create(:vulnerability, :with_read, project: new_project)

        expect { execute_graphql_query }.to issue_same_number_of_queries_as(queries_recorded).with_threshold(4)
      end
    end
  end
end
