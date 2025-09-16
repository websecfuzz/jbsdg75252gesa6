# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create project secret', :gitlab_secrets_manager, feature_category: :secrets_management do
  include GraphqlHelpers

  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:mutation_name) { :project_secret_create }
  let(:error_message) do
    "The resource that you are attempting to access does not exist or you don't have permission to perform this action"
  end

  let(:secrets_manager) { create(:project_secrets_manager, project: project) }

  let(:params) do
    {
      project_path: project.full_path,
      name: 'TEST_SECRET',
      description: 'test description',
      secret: 'the-secret-value',
      branch: 'main',
      environment: 'prod'
    }
  end

  let(:mutation) { graphql_mutation(mutation_name, params) }
  let(:mutation_response) { graphql_mutation_response(mutation_name) }

  subject(:post_mutation) { post_graphql_mutation(mutation, current_user: current_user) }

  before do
    stub_last_activity_update
    provision_project_secrets_manager(secrets_manager, current_user)
  end

  context 'when current user is not part of the project' do
    it_behaves_like 'a mutation on an unauthorized resource'
  end

  context 'when current user is project maintainer, but has no openbao policies' do
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

  context 'when current user is the project owner and has proper openbao policies' do
    before_all do
      project.add_owner(current_user)
    end

    it_behaves_like 'internal event tracking' do
      let(:event) { 'create_ci_secret' }
      let(:user) { current_user }
      let(:namespace) { project.namespace }
      let(:additional_properties) { { label: 'graphql' } }
      let(:category) { 'Mutations::SecretsManagement::ProjectSecrets::Create' }
    end

    it 'creates the project secret', :aggregate_failures do
      post_mutation

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['errors']).to be_empty

      expect(graphql_data_at(mutation_name, :project_secret))
        .to match(a_graphql_entity_for(
          project: a_graphql_entity_for(project),
          name: params[:name],
          description: params[:description],
          branch: params[:branch],
          environment: params[:environment],
          metadata_version: 1
        ))
    end

    context 'and service results to a failure' do
      before do
        allow_next_instance_of(SecretsManagement::ProjectSecrets::CreateService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.error(message: 'some error'))
        end
      end

      it 'returns the service error' do
        expect_next_instance_of(SecretsManagement::ProjectSecrets::CreateService) do |service|
          project_secret = SecretsManagement::ProjectSecret.new
          project_secret.errors.add(:base, 'some error')

          result = ServiceResponse.error(message: 'some error', payload: { project_secret: project_secret })
          expect(service).to receive(:execute).and_return(result)
        end

        post_mutation

        expect(mutation_response['errors']).to include('some error')
      end

      it_behaves_like 'internal event not tracked'
    end

    context 'and value exceed allowed limits (10k characters)' do
      let(:params) do
        {
          project_path: project.full_path,
          name: 'TEST_SECRET_1234',
          description: 'test description',
          secret: "x" * 10001,
          branch: 'main',
          environment: 'prod'
        }
      end

      it 'fails', :aggregate_failures do
        post_mutation

        msg = 'Length of project secret value exceeds allowed limits (10k bytes).'
        expect(mutation_response['errors']).to include(msg)
      end
    end

    context 'and name does not conform' do
      let(:params) do
        {
          project_path: project.full_path,
          name: '../../OTHER_SECRET',
          description: 'test description',
          secret: 'Secret123',
          branch: 'main',
          environment: 'prod'
        }
      end

      it 'fails', :aggregate_failures do
        post_mutation

        expect(mutation_response['errors']).to include("Name can contain only letters, digits and '_'.")
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
