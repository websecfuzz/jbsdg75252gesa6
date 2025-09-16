# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Getting secret permissions', :gitlab_secrets_manager, feature_category: :secrets_management do
  include GraphqlHelpers
  include SecretsManagement::GitlabSecretsManagerHelpers

  let_it_be(:group) { create(:group) }
  let(:error_message) do
    /The resource that you are attempting to access does not exist or you don't have permission to perform this action/i
  end

  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:secrets_manager) { create(:project_secrets_manager, project: project) }

  let(:query) do
    <<~GQL
      query GetSecretPermissions($projectPath: ID!) {
        secretPermissions(projectPath: $projectPath) {
          edges {
            node {
              #{all_graphql_fields_for('SecretPermission')}
            }
          }
        }
      }
    GQL
  end

  let(:query_variables) { { projectPath: project.full_path } }

  subject(:post_graphql_query) { post_graphql(query, variables: query_variables, current_user: current_user) }

  context 'when the user has permissions' do
    before_all do
      project.add_owner(current_user)
    end

    before do
      provision_project_secrets_manager(secrets_manager, current_user)

      update_secret_permission(
        user: current_user, project: project, permissions: %w[create
          update read], principal: { id: current_user.id, type: 'User' }
      )
      update_secret_permission(
        user: current_user, project: project, permissions: %w[create read], principal: { id: 20, type: 'Role' }
      )
    end

    it 'returns secret permissions' do
      post_graphql_query

      expect(response).to have_gitlab_http_status(:success)

      permissions_data = graphql_data_at['secretPermissions']['edges'].pluck('node')
      expect(permissions_data.length).to eq(3)

      expect(permissions_data).to include(
        a_hash_including(
          'principal' => { 'id' => current_user.id.to_s, 'type' => 'User' }
        ).and(satisfy { |data|
                data['permissions'].include?('create') &&
                              data['permissions'].include?('update') &&
                              data['permissions'].include?('read')
              }),
        a_hash_including(
          'principal' => { 'id' => '20', 'type' => 'Role' }
        ).and(satisfy { |data|
                data['permissions'].include?('create') &&
                              data['permissions'].include?('read')
              })
      )
    end

    context 'and service results to a failure' do
      before do
        allow_next_instance_of(SecretsManagement::Permissions::ListService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.error(message: 'some error'))
        end
      end

      it 'returns the service error' do
        expect_next_instance_of(SecretsManagement::Permissions::ListService) do |service|
          secret_permission = SecretsManagement::SecretPermission.new
          secret_permission.errors.add(:base, 'some error')

          result = ServiceResponse.error(message: 'some error', payload: { secret_permission: secret_permission })
          expect(service).to receive(:execute).and_return(result)
        end

        post_graphql_query

        expect(graphql_errors).to include(a_hash_including('message' => 'some error'))
      end
    end
  end

  context 'when the user does not have permissions' do
    it 'returns an error' do
      post_graphql_query

      expect(response).to have_gitlab_http_status(:success)
      expect(graphql_errors).to include(a_hash_including('message' => error_message))
    end
  end

  context 'when the project does not exist' do
    let(:query_variables) { { projectPath: 'non/existent/project' } }

    it 'returns an error' do
      post_graphql_query

      expect(response).to have_gitlab_http_status(:success)
      expect(graphql_errors).to include(a_hash_including('message' => error_message))
    end
  end

  context 'when list service fails' do
    before_all do
      project.add_maintainer(current_user)
    end

    it 'returns a GraphQL error with the service error message' do
      post_graphql_query

      expect(response).to have_gitlab_http_status(:success)
      expect(graphql_errors).to include(a_hash_including('message' => error_message))
    end

    it 'does not return any secret permissions data' do
      post_graphql_query

      expect(graphql_data['secretPermissions']).to be_nil
    end
  end

  context 'when project secrets manager is not active' do
    let_it_be(:project) { create(:project) }
    let(:query) do
      graphql_query_for(
        :secretPermissions,
        { projectPath: project.full_path }
      )
    end

    before do
      allow_next_instance_of(::SecretsManagement::ProjectSecretsManager) do |manager|
        allow(manager).to receive(:active?).and_return(false)
      end

      post_graphql(query, current_user: current_user)
    end

    it 'raises a resource not available error' do
      expect(graphql_errors).to include(
        a_hash_including('message' => error_message)
      )
    end
  end
end
