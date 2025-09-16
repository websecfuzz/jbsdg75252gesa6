# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Update project secret', :gitlab_secrets_manager, feature_category: :secrets_management do
  include GraphqlHelpers

  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:owner_user) { create(:user) }
  let_it_be(:mutation_name) { :project_secret_update }
  let(:error_message) do
    "The resource that you are attempting to access does not exist or you don't have permission to perform this action"
  end

  let(:secrets_manager) { create(:project_secrets_manager, project: project) }

  let(:project_secret_attributes) do
    {
      name: 'TEST_SECRET',
      description: 'test description',
      branch: 'main',
      environment: 'prod',
      value: 'test value'
    }
  end

  let(:params) do
    {
      project_path: project.full_path,
      name: project_secret_attributes[:name],
      description: 'updated description',
      branch: 'feature',
      environment: 'staging',
      metadata_cas: 1
    }
  end

  let(:mutation) { graphql_mutation(mutation_name, params) }
  let(:mutation_response) { graphql_mutation_response(mutation_name) }

  subject(:post_mutation) { post_graphql_mutation(mutation, current_user: current_user) }

  before_all do
    project.add_owner(owner_user)
  end

  before do
    provision_project_secrets_manager(secrets_manager, owner_user)
    stub_last_activity_update

    create_project_secret(
      **project_secret_attributes.merge(user: owner_user, project: project)
    )
  end

  context 'when current user is not part of the project' do
    it_behaves_like 'a mutation on an unauthorized resource'
  end

  context 'when current user is maintainer, but has no openbao policies' do
    before_all do
      project.add_maintainer(current_user)
    end

    it 'returns permission error from Openbao' do
      post_mutation

      expect(response).to have_gitlab_http_status(:error)
      expect(graphql_errors).to be_present
      expect(graphql_errors.first['message']).to include("permission denied")
    end
  end

  context 'when current user is the project owner and has proper policies in Openbao' do
    before_all do
      project.add_owner(current_user)
    end

    it_behaves_like 'internal event tracking' do
      let(:event) { 'update_ci_secret' }
      let(:user) { current_user }
      let(:namespace) { project.namespace }
      let(:additional_properties) { { label: 'graphql' } }
      let(:category) { 'Mutations::SecretsManagement::ProjectSecrets::Update' }
    end

    it 'updates the project secret', :aggregate_failures do
      post_mutation

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['errors']).to be_empty

      expect(graphql_data_at(mutation_name, :project_secret))
        .to match(a_graphql_entity_for(
          project: a_graphql_entity_for(project),
          name: project_secret_attributes[:name],
          description: 'updated description',
          branch: 'feature',
          environment: 'staging',
          metadata_version: 2
        ))
    end

    context 'with partial updates' do
      let(:params) do
        {
          project_path: project.full_path,
          name: project_secret_attributes[:name],
          description: 'updated description',
          metadata_cas: 1
        }
      end

      it 'updates only the specified fields', :aggregate_failures do
        post_mutation

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to be_empty

        expect(graphql_data_at(mutation_name, :project_secret))
          .to match(a_graphql_entity_for(
            name: project_secret_attributes[:name],
            description: 'updated description',
            branch: project_secret_attributes[:branch],
            environment: project_secret_attributes[:environment],
            metadata_version: 2
          ))

        # Can't check the value directly in GraphQL response, but we can verify it was updated
        secret_path = secrets_manager.ci_data_path(project_secret_attributes[:name])
        expect_kv_secret_to_have_value(
          project.secrets_manager.ci_secrets_mount_path,
          secret_path,
          'test value'
        )
      end
    end

    context 'with value update' do
      let(:params) do
        {
          project_path: project.full_path,
          name: project_secret_attributes[:name],
          secret: 'new-secret-value',
          metadata_cas: 1
        }
      end

      it 'updates the value', :aggregate_failures do
        post_mutation

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to be_empty

        expect(graphql_data_at(mutation_name, :project_secret))
          .to match(a_graphql_entity_for(
            metadata_version: 2
          ))

        # Can't check the value directly in GraphQL response, but we can verify it was updated
        secret_path = secrets_manager.ci_data_path(project_secret_attributes[:name])
        expect_kv_secret_to_have_value(
          project.secrets_manager.ci_secrets_mount_path,
          secret_path,
          'new-secret-value'
        )
      end
    end

    context 'when metadata_cas is not provided' do
      let(:params) do
        {
          project_path: project.full_path,
          name: project_secret_attributes[:name],
          description: 'updated description',
          branch: 'feature',
          environment: 'staging'
        }
      end

      it 'updates the project secret', :aggregate_failures do
        post_mutation

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to be_empty

        expect(graphql_data_at(mutation_name, :project_secret))
          .to match(a_graphql_entity_for(
            project: a_graphql_entity_for(project),
            name: project_secret_attributes[:name],
            description: 'updated description',
            branch: 'feature',
            environment: 'staging',
            metadata_version: nil
          ))
      end
    end

    context 'when secret does not exist' do
      let(:params) do
        {
          project_path: project.full_path,
          name: 'NON_EXISTENT_SECRET',
          description: 'updated description',
          metadata_cas: 1
        }
      end

      it 'returns a top-level error with message' do
        post_mutation

        expect(mutation_response).to be_nil
        expect(graphql_errors.count).to eq(1)
        expect(graphql_errors.first['message']).to eq('Project secret does not exist.')
      end

      it_behaves_like 'internal event not tracked'
    end

    context 'and service results to a failure' do
      before do
        allow_next_instance_of(SecretsManagement::ProjectSecrets::UpdateService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.error(message: 'some error'))
        end
      end

      it 'returns the service error' do
        expect_next_instance_of(SecretsManagement::ProjectSecrets::UpdateService) do |service|
          project_secret = SecretsManagement::ProjectSecret.new
          project_secret.errors.add(:base, 'some error')

          result = ServiceResponse.error(message: 'some error', payload: { project_secret: project_secret })
          expect(service).to receive(:execute).and_return(result)
        end

        post_mutation

        expect(mutation_response['errors']).to include('some error')
      end
    end

    context 'and secrets_manager feature flag is disabled' do
      it 'returns an error' do
        stub_feature_flags(secrets_manager: false)

        post_mutation

        expect_graphql_errors_to_include(error_message)
      end
    end
  end
end
