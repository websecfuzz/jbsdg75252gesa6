# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting group label information', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:parent_group) { create(:group) }
  let_it_be(:group) { create(:group, :public, parent: parent_group) }
  let_it_be(:label_factory) { :group_label }
  let_it_be(:label_attrs) { { group: group } }

  it_behaves_like 'querying a GraphQL type with labels' do
    let(:path_prefix) { ['group'] }

    def make_query(fields)
      graphql_query_for('group', { full_path: group.full_path }, fields)
    end
  end

  context 'when searching title within a hierarchy' do
    let_it_be(:current_user) { create(:user) }
    let_it_be(:labels_params) { { title: 'priority::1', includeAncestorGroups: true, includeDescendantGroups: true } }
    let_it_be(:project) { create(:project, :public, namespace: group) }
    let_it_be(:subgroup) { create(:group, :public, parent: group) }
    let_it_be(:project_label) { create(:label, project: project, title: 'priority::1', color: '#FF0000') }
    let_it_be(:parent_group_label) { create(:group_label, group: parent_group, title: 'priority::1', color: '#FF00FF') }
    let_it_be(:subgroup_label) { create(:group_label, group: subgroup, title: 'priority::1', color: '#000000') }

    let(:labels_response) { graphql_data.dig('group', 'labels', 'nodes') }
    let(:query) do
      graphql_query_for('group', { full_path: group.full_path }, [
        query_graphql_field(:labels, labels_params, [query_graphql_field(:nodes, nil, %w[id title])])
      ])
    end

    it 'finds the labels with exact title matching' do
      post_graphql(query, current_user: current_user)
      expect(graphql_errors).not_to be_present

      expect(labels_response.pluck('id')).to contain_exactly(
        *[project_label, parent_group_label, subgroup_label].map { |l| l.to_global_id.to_s }
      )
    end
  end

  describe 'preventing N+1 queries', :saas do
    let_it_be(:group) { create(:group_with_plan, :private, plan: :ultimate_plan) }
    let_it_be(:sub_group) { create(:group, :private, parent: group) }
    let_it_be(:sub_sub_group) { create(:group, :private, parent: sub_group) }

    let_it_be(:sub_group_project) { create(:project, group: sub_group) }
    let_it_be(:sub_sub_group_project) { create(:project, group: sub_sub_group) }
    let_it_be(:group_project) { create(:project, group: group) }

    let_it_be(:sub_group_project_label) { create(:label, project: sub_group_project, title: 'aaa') }
    let_it_be(:sub_sub_group_project_label1) { create(:label, project: sub_sub_group_project, title: 'bbb') }
    let_it_be(:sub_sub_group_project_label2) { create(:label, project: sub_sub_group_project, title: 'bbbb') }

    let_it_be(:group_label) { create(:group_label, group: group, title: 'ccc') }
    let_it_be(:sub_group_label1) { create(:group_label, group: sub_group, title: 'ddd') }
    let_it_be(:sub_group_label2) { create(:group_label, group: sub_group, title: 'dddd') }
    let_it_be(:sub_sub_group_label) { create(:group_label, group: sub_sub_group, title: 'eee') }

    let(:query) do
      <<~QUERY
        query($path: ID!) {
          group(fullPath: $path) {
            labels(includeAncestorGroups: true, includeDescendantGroups: true, onlyGroupLabels: false) {
              nodes {
                id
                title
              }
            }
          }
        }
      QUERY
    end

    let_it_be(:current_user) { create(:user, developer_of: group) }

    def run_query
      post_graphql(query, current_user: current_user, variables: { path: group.full_path })
    end

    before do
      stub_ee_application_setting(should_check_namespace_plan: true)
      stub_licensed_features(group_ip_restriction: true, group_saml: true)
    end

    subject(:titles) do
      run_query

      graphql_data.dig('group', 'labels', 'nodes').pluck('title')
    end

    it 'returns the project and group labels' do
      expected_titles = [
        sub_group_project_label,
        sub_sub_group_project_label1,
        sub_sub_group_project_label2,
        group_label,
        sub_group_label1,
        sub_group_label2,
        sub_sub_group_label
      ].map(&:title)

      expect(titles).to eq(expected_titles)
    end
  end
end
