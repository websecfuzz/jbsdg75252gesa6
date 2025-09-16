# frozen_string_literal: true
require 'spec_helper'

RSpec.describe 'getting container repositories in a project', feature_category: :container_registry do
  using RSpec::Parameterized::TableSyntax
  include GraphqlHelpers

  let_it_be_with_reload(:project) { create(:project, :private) }
  let_it_be(:container_repository) { create(:container_repository, project: project) }
  let_it_be(:container_repositories_delete_scheduled) { create_list(:container_repository, 2, :status_delete_scheduled, project: project) }
  let_it_be(:container_repositories_delete_failed) { create_list(:container_repository, 2, :status_delete_failed, project: project) }
  let_it_be(:container_repositories) { [container_repository, container_repositories_delete_scheduled, container_repositories_delete_failed].flatten }
  let_it_be(:container_expiration_policy) { project.container_expiration_policy }

  let(:excluded_fields) { %w[pipeline jobs productAnalyticsState mlModels mergeTrains mlExperiments] }
  let(:container_repositories_fields) do
    <<~GQL
      edges {
        node {
          #{all_graphql_fields_for('container_repositories'.classify, excluded: excluded_fields)}
        }
      }
    GQL
  end

  let(:fields) do
    <<~GQL
      #{query_graphql_field('container_repositories', {}, container_repositories_fields)}
      containerRepositoriesCount
    GQL
  end

  let(:query) do
    graphql_query_for(
      'project',
      { 'fullPath' => project.full_path },
      fields
    )
  end

  let(:user) { project.first_owner }
  let(:variables) { {} }
  let(:container_repositories_response) { graphql_data.dig('project', 'containerRepositories', 'edges') }
  let(:container_repositories_count_response) { graphql_data.dig('project', 'containerRepositoriesCount') }

  before do
    stub_container_registry_config(enabled: true)
    container_repositories.each do |repository|
      stub_container_registry_tags(repository: repository.path, tags: %w[tag1 tag2 tag3], with_manifest: false)
    end
  end

  subject { post_graphql(query, current_user: user, variables: variables) }

  it_behaves_like 'a working graphql query' do
    before do
      subject
    end

    it 'matches the JSON schema' do
      expect(container_repositories_response).to match_schema('graphql/container_repositories')
    end
  end

  context 'with different permissions' do
    let_it_be(:user) { create(:user) }

    where(:project_visibility, :role, :access_granted, :destroy_container_repository) do
      :private | :maintainer | true  | true
      :private | :developer  | true  | true
      :private | :reporter   | true  | false
      :private | :guest      | false | false
      :private | :anonymous  | false | false
      :public  | :maintainer | true  | true
      :public  | :developer  | true  | true
      :public  | :reporter   | true  | false
      :public  | :guest      | true  | false
      :public  | :anonymous  | true  | false
    end

    with_them do
      before do
        project.update!(visibility_level: Gitlab::VisibilityLevel.const_get(project_visibility.to_s.upcase, false))
        project.add_member(user, role) unless role == :anonymous
      end

      it 'return the proper response' do
        subject

        if access_granted
          expect(container_repositories_response.size).to eq(container_repositories.size)
          container_repositories_response.each do |repository_response|
            expect(repository_response.dig('node', 'userPermissions', 'destroyContainerRepository')).to eq(destroy_container_repository)
          end
        else
          expect(container_repositories_response).to eq(nil)
        end
      end
    end
  end

  context 'limiting the number of repositories' do
    let(:limit) { 1 }
    let(:variables) do
      { path: project.full_path, n: limit }
    end

    let(:query) do
      <<~GQL
        query($path: ID!, $n: Int) {
          project(fullPath: $path) {
            containerRepositories(first: $n) { #{container_repositories_fields} }
          }
        }
      GQL
    end

    it 'only returns N repositories' do
      subject

      expect(container_repositories_response.size).to eq(limit)
    end
  end

  context 'filter by name' do
    let_it_be(:container_repository) { create(:container_repository, name: 'fooBar', project: project) }

    let(:name) { 'ooba' }
    let(:query) do
      <<~GQL
        query($path: ID!, $name: String) {
          project(fullPath: $path) {
            containerRepositories(name: $name) { #{container_repositories_fields} }
          }
        }
      GQL
    end

    let(:variables) do
      { path: project.full_path, name: name }
    end

    before do
      stub_container_registry_tags(repository: container_repository.path, tags: %w[tag4 tag5 tag6], with_manifest: false)
    end

    it 'returns the searched container repository' do
      subject

      expect(container_repositories_response.size).to eq(1)
      expect(container_repositories_response.first.dig('node', 'id')).to eq(container_repository.to_global_id.to_s)
    end
  end

  it_behaves_like 'handling graphql network errors with the container registry'

  it_behaves_like 'not hitting graphql network errors with the container registry' do
    let(:excluded_fields) { %w[pipeline jobs tags tagsCount productAnalyticsState mlModels mergeTrains mlExperiments] }
  end

  it 'returns the total count of container repositories' do
    subject

    expect(container_repositories_count_response).to eq(container_repositories.size)
  end

  describe 'sorting and pagination' do
    let_it_be(:data_path) { [:project, :container_repositories] }
    let_it_be(:sort_project) { create(:project, :public) }
    let_it_be(:current_user) { create(:user) }
    let_it_be(:container_repository1) { create(:container_repository, name: 'b', project: sort_project) }
    let_it_be(:container_repository2) { create(:container_repository, name: 'a', project: sort_project) }
    let_it_be(:container_repository3) { create(:container_repository, name: 'd', project: sort_project) }
    let_it_be(:container_repository4) { create(:container_repository, name: 'c', project: sort_project) }
    let_it_be(:container_repository5) { create(:container_repository, name: 'e', project: sort_project) }

    before do
      stub_container_registry_tags(repository: container_repository1.path, tags: %w[tag1 tag1 tag3], with_manifest: false)
      stub_container_registry_tags(repository: container_repository2.path, tags: %w[tag4 tag5 tag6], with_manifest: false)
      stub_container_registry_tags(repository: container_repository3.path, tags: %w[tag7 tag8], with_manifest: false)
      stub_container_registry_tags(repository: container_repository4.path, tags: %w[tag9], with_manifest: false)
      stub_container_registry_tags(repository: container_repository5.path, tags: %w[tag10 tag11], with_manifest: false)
    end

    def pagination_query(params)
      graphql_query_for(:project, { full_path: sort_project.full_path },
        query_nodes(:container_repositories, :name, include_pagination_info: true, args: params)
      )
    end

    def pagination_results_data(data)
      # rubocop:disable Rails/Pluck -- doing .pluck is only valid inside model hence disabling
      data.map { |container_repository| container_repository['name'] }
      # rubocop:enable Rails/Pluck
    end

    context 'when sorting by name' do
      context 'when ascending' do
        it_behaves_like 'sorted paginated query' do
          let(:sort_param) { :NAME_ASC }
          let(:first_param) { 2 }
          let(:all_records) { [container_repository2.name, container_repository1.name, container_repository4.name, container_repository3.name, container_repository5.name] }
        end
      end

      context 'when descending' do
        it_behaves_like 'sorted paginated query' do
          let(:sort_param) { :NAME_DESC }
          let(:first_param) { 2 }
          let(:all_records) { [container_repository5.name, container_repository3.name, container_repository4.name, container_repository1.name, container_repository2.name] }
        end
      end
    end
  end

  describe 'protectionRuleExists' do
    let_it_be(:container_registry_protection_rule) do
      create(:container_registry_protection_rule, project: project, repository_path_pattern: container_repository.path)
    end

    it 'returns true for the field "protectionRuleExists" for the protected container respository' do
      subject

      expect(container_repositories_response).to include 'node' => hash_including('path' => container_repository.path, 'protectionRuleExists' => true)

      container_repositories_response
        .reject { |cr| cr.dig('node', 'path') == container_repository.path }
        .each do |repository_response|
          expect(repository_response.dig('node', 'protectionRuleExists')).to eq false
        end
    end

    # In order to trigger the N+1 query, we need to create project with different container repository counts.
    # In this case, project1 has 4 container repositories and project2 has 10 container repositories.
    describe "efficient database queries" do
      let_it_be(:project1) { create(:project, :private) }
      let_it_be(:user1) { create(:user, developer_of: project1) }
      let_it_be(:project1_container_repositories) { create_list(:container_repository, 4, project: project1) }
      let_it_be(:project1_container_repository_protected) { project1_container_repositories.first }
      let_it_be(:project1_npm_container_protection_rule) do
        create(:container_registry_protection_rule,
          project: project1,
          repository_path_pattern: project1_container_repository_protected.path
        )
      end

      let_it_be(:project2) { create(:project, :private) }
      let_it_be(:user2) { create(:user, developer_of: project2) }
      let_it_be(:project2_container_repositories) { create_list(:container_repository, 8, project: project2) }
      let_it_be(:project2_container_repository_protected) { project2_container_repositories.first }
      let_it_be(:project2_npm_container_protection_rule) do
        create(:container_registry_protection_rule,
          project: project2,
          repository_path_pattern: project2_container_repository_protected.path
        )
      end

      let(:fields) do
        <<~GQL
          containerRepositories {
            nodes {
              path
              protectionRuleExists
            }
          }
        GQL
      end

      before do
        project1_container_repositories.each do |repository|
          stub_container_registry_tags(repository: repository.path, tags: %w[tag1 tag2 tag3], with_manifest: false)
        end

        project2_container_repositories.each do |repository|
          stub_container_registry_tags(repository: repository.path, tags: %w[tag1 tag2 tag3], with_manifest: false)
        end
      end

      it 'avoids N+1 database queries' do
        query1 = graphql_query_for('project', { 'fullPath' => project1.full_path }, fields)
        control_count1 = ActiveRecord::QueryRecorder.new { post_graphql(query1, current_user: user1) }

        query2 = graphql_query_for('project', { 'fullPath' => project2.full_path }, fields)
        expect { post_graphql(query2, current_user: user2) }.not_to exceed_query_limit(control_count1)
      end
    end
  end

  describe 'destroyContainerRepository' do
    describe 'efficient database queries' do
      let_it_be(:project) { create(:project, :private) }
      let_it_be(:project_container_repositories) { create_list(:container_repository, 2, project: project) }

      let(:fields) do
        <<~GQL
          containerRepositories {
            nodes {
              userPermissions {
                destroyContainerRepository
              }
            }
          }
        GQL
      end

      before_all do
        create(:container_registry_protection_tag_rule,
          project: project,
          tag_name_pattern: 'x'
        )
      end

      before do
        project_container_repositories.each do |repository|
          stub_container_registry_tags(repository: repository.path, tags: %w[tag1 tag2 tag3], with_manifest: false)
        end
      end

      it 'avoids N+1 database queries', :use_sql_query_cache do
        query = graphql_query_for('project', { 'fullPath' => project.full_path }, fields)

        first_user = create(:user, developer_of: project)
        control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
          post_graphql(query, current_user: first_user)
        end

        second_user = create(:user, developer_of: project)
        new_repositories = create_list(:container_repository, 2, project: project)
        new_repositories.each do |repository|
          stub_container_registry_tags(repository: repository.path, tags: %w[tag1 tag2 tag3], with_manifest: false)
        end

        expect do
          post_graphql(query, current_user: second_user)
        end.to issue_same_number_of_queries_as(control)
      end
    end
  end
end
