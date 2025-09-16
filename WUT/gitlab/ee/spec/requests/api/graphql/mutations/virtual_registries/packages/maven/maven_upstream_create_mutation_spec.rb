# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create an upstream registry', feature_category: :virtual_registry do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:registry) { create(:virtual_registries_packages_maven_registry, group: group) }

  let(:mutation_params) do
    {
      id: ::Gitlab::GlobalId.as_global_id(registry.id,
        model_name: 'VirtualRegistries::Packages::Maven::Registry'),
      name: 'Maven Central',
      url: 'https://repo.maven.apache.org/maven2',
      cache_validity_hours: 24
    }
  end

  let(:faulty_mutation_params) do
    {
      **mutation_params,
      url: 'file://repo.maven.apache.org/maven2',
      cache_validity_hours: 'no'
    }
  end

  let(:mutation_response) { graphql_mutation_response(:maven_upstream_create) }

  def maven_upstream_mutation(params = mutation_params)
    graphql_mutation(:mavenUpstreamCreate, params)
  end

  before_all do
    group.add_owner(current_user)
  end

  before do
    stub_config(dependency_proxy: { enabled: true })
    stub_licensed_features(packages_virtual_registry: true)
  end

  it 'creates the maven upstream registry' do
    post_graphql_mutation(maven_upstream_mutation, current_user: current_user)

    expect(response).to have_gitlab_http_status(:success)
    expect(mutation_response['upstream']).to match(
      a_hash_including(
        "name" => 'Maven Central',
        "cacheValidityHours" => 24,
        "url" => 'https://repo.maven.apache.org/maven2'
      )
    )
  end

  it 'returns an error if the mutation params are invalid' do
    error_msg = "Variable $mavenUpstreamCreateInput of type MavenUpstreamCreateInput! " \
      "was provided invalid value for cacheValidityHours (Could not coerce value \"no\" to Int)"

    post_graphql_mutation(maven_upstream_mutation(faulty_mutation_params), current_user: current_user)

    expect(response).to have_gitlab_http_status(:success)
    expect(graphql_errors[0]['message']).to eq(error_msg)
  end

  context 'with maven_virtual_registry feature flag turned off' do
    before do
      stub_feature_flags(maven_virtual_registry: false)
    end

    it 'raises an exception' do
      error_msg = "The resource that you are attempting to access does " \
        "not exist or you don't have permission to perform this action"
      post_graphql_mutation(maven_upstream_mutation, current_user: current_user)

      expect(graphql_errors).to include(a_hash_including('message' => error_msg))
    end
  end
end
