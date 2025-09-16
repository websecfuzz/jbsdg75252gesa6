# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting the framework coverage details for a group', feature_category: :compliance_management do
  include GraphqlHelpers

  let_it_be(:root_group) { create(:group) }
  let_it_be(:sub_group) { create(:group, parent: root_group) }
  let_it_be(:current_user) { create(:user) }

  let_it_be(:root_project) { create(:project, group: root_group) }
  let_it_be(:sub_project1) { create(:project, group: sub_group) }
  let_it_be(:sub_project2) { create(:project, group: sub_group) }

  let_it_be(:framework1) { create(:compliance_framework, namespace: root_group, name: 'SOC2') }
  let_it_be(:framework2) { create(:compliance_framework, namespace: root_group, name: 'GDPR') }

  let(:fields) do
    <<~GRAPHQL
      nodes {
        id
        framework {
          name
        }
        coveredCount
      }
    GRAPHQL
  end

  let(:framework_details) { graphql_data_at(:group, :compliance_frameworks_coverage_details, :nodes) }

  def query(group_path = sub_group.full_path)
    graphql_query_for(
      :group, { full_path: group_path },
      query_graphql_field("complianceFrameworksCoverageDetails", {}, fields)
    )
  end

  before do
    stub_licensed_features(group_level_compliance_dashboard: true)
  end

  shared_examples 'returns nil' do
    it 'returns nil' do
      post_graphql(query, current_user: current_user)

      expect(framework_details).to be_nil
    end
  end

  context 'when the user is unauthorized' do
    context 'when not part of the group' do
      it_behaves_like 'returns nil'
    end

    context 'with maintainer access' do
      before_all do
        sub_group.add_maintainer(current_user)
      end

      it_behaves_like 'returns nil'
    end
  end

  context 'when the user is authorized' do
    before_all do
      root_group.add_owner(current_user)
    end

    it_behaves_like 'a working graphql query' do
      before do
        post_graphql(query, current_user: current_user)
      end
    end

    context 'when querying from a subgroup' do
      before_all do
        create(:compliance_framework_project_setting,
          compliance_management_framework: framework1,
          project: root_project)
        create(:compliance_framework_project_setting,
          compliance_management_framework: framework1,
          project: sub_project1)
        create(:compliance_framework_project_setting,
          compliance_management_framework: framework1,
          project: sub_project2)

        create(:compliance_framework_project_setting,
          compliance_management_framework: framework2,
          project: sub_project1)
      end

      it 'returns root frameworks with coverage counts for subgroup projects only' do
        post_graphql(query(sub_group.full_path), current_user: current_user)
        expect(framework_details.pluck('framework', 'coveredCount')).to contain_exactly(
          [{ "name" => "GDPR" }, 1],
          [{ "name" => "SOC2" }, 2]
        )
      end

      it 'does not include other groups frameworks' do
        other_root_group = create(:group)
        create(:compliance_framework, namespace: other_root_group, name: 'Other')

        post_graphql(query(sub_group.full_path), current_user: current_user)
        framework_names = framework_details.map { |detail| detail["framework"]["name"] }
        expect(framework_names).not_to include('Other')
      end
    end

    context 'when querying from root group' do
      before_all do
        create(:compliance_framework_project_setting,
          compliance_management_framework: framework1,
          project: root_project)
      end

      it 'returns frameworks with coverage counts for all projects' do
        post_graphql(query(root_group.full_path), current_user: current_user)

        expect(framework_details.pluck('framework', 'coveredCount')).to contain_exactly(
          [{ "name" => "GDPR" }, 0],
          [{ "name" => "SOC2" }, 1]
        )
      end
    end

    context 'when group has no projects' do
      let_it_be(:empty_group) { create(:group) }

      before_all do
        empty_group.add_owner(current_user)
      end

      it 'returns empty array' do
        post_graphql(query(empty_group.full_path), current_user: current_user)

        expect(graphql_data_at(:group, :compliance_frameworks_coverage_details, :nodes)).to eq([])
      end
    end
  end
end
