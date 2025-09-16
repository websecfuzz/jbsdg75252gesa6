# frozen_string_literal: true

RSpec.shared_examples 'sbom dependency node' do
  let(:expected_parent_path) { defined?(group) ? group.full_path : project.full_path }
  let(:subject_entity) { defined?(group) ? :group : :project }
  let(:nodes_path) { defined?(group) ? %i[group dependencyAggregations nodes] : %i[project dependencies nodes] }
  let(:query_base_args) { defined?(group) ? { fullPath: expected_parent_path } : { full_path: expected_parent_path } }
  let(:licensed_features) { { dependency_scanning: true } }

  before do
    stub_licensed_features(**licensed_features)
  end

  it 'returns the expected dependency data when performing a well-formed query with an authorized user' do
    post_graphql(query, current_user: current_user)

    actual = graphql_data_at(*nodes_path)
    expect(actual).not_to be_nil
    expect(actual).to include(a_hash_including('name' => occurrences.first.name))
  end

  context 'with an unauthorized user' do
    let_it_be(:current_user) { create(:user) }

    it 'does not return dependency data' do
      post_graphql(query, current_user: current_user)

      root_path = nodes_path[0...-1]
      expect(graphql_data_at(*root_path)).to be_blank
    end
  end

  it 'does not make N+1 queries' do
    control = ActiveRecord::QueryRecorder.new { post_graphql(query, current_user: current_user) }

    create(:sbom_occurrence, project: project)

    expect { post_graphql(query, current_user: current_user) }.not_to exceed_query_limit(control)
  end
end

RSpec.shared_context 'when dependencies graphql query sorted paginated' do
  def pagination_results_data(nodes)
    nodes.pluck('id')
  end

  let(:data_path) { defined?(group) ? %i[group dependencyAggregations] : %i[project dependencies] }
  let(:sort_argument) { {} }
  let(:first_param) { 2 }
  let(:all_records) { occurrences.sort_by(&:id).map { |occurrence| occurrence.to_gid.to_s } }
end

RSpec.shared_examples 'when dependencies graphql query sorted by severity' do
  context 'with sort as an argument' do
    let(:desc_query) { pagination_query({ sort: :SEVERITY_DESC }) }
    let(:asc_query) { pagination_query({ sort: :SEVERITY_ASC }) }

    it 'sorts by severity descending' do
      post_graphql(desc_query, current_user: current_user)

      severities = graphql_data_at(*nodes_path).pluck('vulnerabilityCount')
      expect(severities).to eq(severities.sort.reverse)
    end

    it 'sorts by severity ascending' do
      post_graphql(asc_query, current_user: current_user)

      severities = graphql_data_at(*nodes_path).pluck('vulnerabilityCount')
      expect(severities).to eq(severities.sort)
    end
  end
end

RSpec.shared_examples 'when dependencies graphql query sorted by license' do
  context 'with sort as an argument' do
    let(:asc_query) { pagination_query({ sort: :LICENSE_ASC }) }
    let(:desc_query) { pagination_query({ sort: :LICENSE_DESC }) }

    it 'sorts by license ascending' do
      post_graphql(asc_query, current_user: current_user)

      licenses = graphql_data_at(*nodes_path).pluck('license')
      expect(licenses).to eq(licenses.sort)
    end

    it 'sorts by license descending' do
      post_graphql(desc_query, current_user: current_user)

      licenses = graphql_data_at(*nodes_path).pluck('license')
      expect(licenses).to eq(licenses.sort.reverse)
    end
  end
end

RSpec.shared_examples 'when dependencies graphql query filtered by package manager' do
  it 'returns only matching package manager results' do
    post_graphql(query, current_user: current_user)
    result = graphql_data_at(*nodes_path)
    packagers = result.pluck('packager')

    expect(packagers).to all(eq expected_packager)
  end
end

RSpec.shared_examples 'when dependencies graphql query filtered by component name' do
  let!(:test_occurrence) { create(:sbom_occurrence, project: project) }
  let(:component_name) { test_occurrence.name }
  let(:component_query) { pagination_query({ component_names: [component_name] }) }

  it 'filters records based on the component name' do
    post_graphql(component_query, current_user: current_user)

    result = graphql_data_at(*nodes_path)
    names = result.pluck('name')
    expect(names).to eq([component_name])
  end
end

RSpec.shared_examples 'when dependencies graphql query filtered by source type' do
  let!(:registry_occurrence) { create(:sbom_occurrence, :registry_occurrence, project: project) }
  let(:source_type_query) { pagination_query({ source_types: [:CONTAINER_SCANNING_FOR_REGISTRY] }) }

  it 'filters records based on the source type' do
    post_graphql(source_type_query, current_user: current_user)

    result = graphql_data_at(*nodes_path)
    expect(result).not_to be_empty
  end
end

RSpec.shared_examples 'when dependencies graphql query filtered by component versions' do
  let_it_be(:matching_component_version) { '1.2.3' }
  let_it_be(:other_component_version) { '4.5.6' }
  let_it_be(:matching_occurrence) do
    create(:sbom_occurrence, project: project,
      component_version: create(:sbom_component_version, version: matching_component_version))
  end

  let_it_be(:other_occurrence) do
    create(:sbom_occurrence, project: project,
      component_version: create(:sbom_component_version, version: other_component_version))
  end

  let(:queried_component_version) { [matching_component_version] }
  let(:component_version_query_payload) { { component_versions: queried_component_version } }
  let(:dependencies_query) { pagination_query(component_version_query_payload) }

  context 'when the version filtering is available for the project' do
    it 'returns only records matching the specified component version(s)' do
      post_graphql(dependencies_query, current_user: current_user)

      result_nodes = graphql_data_at(*nodes_path)
      versions_in_result = result_nodes.pluck('version')
      component_versions_in_result = result_nodes.map { |node| node.dig('componentVersion', 'version') }

      expect(component_versions_in_result).to contain_exactly(matching_component_version)
      expect(versions_in_result).to contain_exactly(matching_component_version)
      expect(result_nodes.size).to eq(1)
    end
  end
end

RSpec.shared_examples 'when dependencies graphql query filtered by not component versions' do
  let_it_be(:excluded_component_versions) { ['1.2.3', '1.2.5', '1.2.7'] }
  let_it_be(:included_component_version) { '4.5.6' }
  let_it_be(:excluded_occurrences) do
    excluded_component_versions.map do |version|
      create(:sbom_occurrence, project: project,
        component_version: create(:sbom_component_version, version: version))
    end
  end

  let_it_be(:included_occurrence) do
    create(:sbom_occurrence, project: project,
      component_version: create(:sbom_component_version, version: included_component_version))
  end

  let(:queried_not_component_version) { excluded_component_versions }
  let(:not_component_version_query_payload) { { not_component_versions: queried_not_component_version } }
  let(:dependencies_query) { pagination_query(not_component_version_query_payload) }

  it 'returns only records not matching the specified component version(s)' do
    post_graphql(dependencies_query, current_user: current_user)

    result_nodes = graphql_data_at(*nodes_path)
    versions_in_result = result_nodes.map { |node| node.dig('componentVersion', 'version') }

    expect(versions_in_result).to include(included_component_version)
    expect(versions_in_result).not_to include(*excluded_component_versions)
  end
end
