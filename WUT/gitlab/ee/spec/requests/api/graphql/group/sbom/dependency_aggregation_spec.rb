# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.group(fullPath).dependencyAggregations', feature_category: :dependency_management do
  include ApiHelpers
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:current_user) { create(:user, admin: true, developer_of: group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:component) { create(:sbom_component) }
  let_it_be(:occurrence) { create(:sbom_occurrence, component: component, project: project) }
  let_it_be(:occurrences) { [occurrence] }
  let_it_be(:variables) { { fullPath: group.full_path } }
  let_it_be(:fields) do
    <<~FIELDS
      name
      version
      componentVersion {
        id
        version
      }
      packager
      vulnerabilityCount
      occurrenceCount
    FIELDS
  end

  let(:query) { pagination_query }
  let(:nodes_path) { %i[group dependencyAggregations nodes] }

  def pagination_query(params = {})
    nodes = query_nodes(:dependencyAggregations, fields, include_pagination_info: true, args: params)
    graphql_query_for(:group, variables, nodes)
  end

  def package_manager_enum(value)
    Types::Sbom::PackageManagerEnum.values.find { |_, custom_value| custom_value.value == value }.first
  end

  before do
    stub_licensed_features(dependency_scanning: true, security_dashboard: true)
  end

  it_behaves_like 'sbom dependency node' do
    let(:licensed_features) { { dependency_scanning: true, security_dashboard: true } }
  end

  it 'returns aggregated dependencies with occurrence count' do
    post_graphql(query, current_user: current_user)

    expect(graphql_data_at(:group, :dependencyAggregations)).not_to be_nil
    expect(graphql_data_at(:group, :dependencyAggregations, :nodes)).to include(
      a_hash_including(
        'name' => component.name,
        'version' => occurrence.version,
        'componentVersion' => {
          'id' => occurrence.component_version.to_gid.to_s,
          'version' => occurrence.component_version.version
        },
        'occurrenceCount' => 1
      )
    )
  end

  it_behaves_like 'when dependencies graphql query sorted paginated'
  it_behaves_like 'when dependencies graphql query sorted by license'
  it_behaves_like 'when dependencies graphql query filtered by package manager' do
    let(:query) { pagination_query({ package_managers: [:BUNDLER] }) }
    let(:expected_packager) { 'BUNDLER' }
  end

  it_behaves_like 'when dependencies graphql query sorted by severity'
  it_behaves_like 'when dependencies graphql query filtered by component name'
  it_behaves_like 'when dependencies graphql query filtered by source type'
end
