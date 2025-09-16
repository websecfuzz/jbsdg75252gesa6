# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Initialize secrets manager on a project', feature_category: :secrets_management do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:mutation_name) { :project_secrets_manager_initialize }

  let(:mutation) { graphql_mutation(mutation_name, project_path: project.full_path) }
  let(:mutation_response) { graphql_mutation_response(mutation_name) }

  subject(:post_mutation) { post_graphql_mutation(mutation, current_user: current_user) }

  context 'when current user is not part of the project' do
    it_behaves_like 'a mutation on an unauthorized resource'
  end

  context 'when current user is not the project owner' do
    before_all do
      project.add_maintainer(current_user)
    end

    it_behaves_like 'a mutation on an unauthorized resource'
  end

  context 'when current user is the project owner' do
    before_all do
      project.add_owner(current_user)
    end

    it 'initializes the secrets manager on the project', :aggregate_failures do
      post_mutation

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['errors']).to be_empty

      expect(graphql_data_at(mutation_name, :project_secrets_manager))
        .to match(a_graphql_entity_for(
          project: a_graphql_entity_for(project),
          status: 'PROVISIONING'
        ))
    end

    it_behaves_like 'internal event tracking' do
      let(:event) { 'enable_ci_secrets_manager_for_project' }
      let(:namespace) { project.namespace }
      let(:user) { current_user }
      let(:category) { 'Mutations::SecretsManagement::ProjectSecretsManagers::Initialize' }
      let(:additional_properties) { { label: 'graphql' } }
    end

    context 'and service results to a failure' do
      before do
        allow_next_instance_of(SecretsManagement::ProjectSecretsManagers::InitializeService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.error(message: 'some error'))
        end
      end

      it 'returns the service error' do
        expect_next_instance_of(SecretsManagement::ProjectSecretsManagers::InitializeService) do |service|
          result = ServiceResponse.error(message: 'some error')
          expect(service).to receive(:execute).and_return(result)
        end

        post_mutation

        expect(mutation_response['errors']).to include('some error')
      end

      it_behaves_like 'internal event not tracked'
    end

    context 'and secrets_manager feature flag is disabled' do
      it 'returns an error' do
        stub_feature_flags(secrets_manager: false)

        post_mutation

        expect_graphql_errors_to_include("`secrets_manager` feature flag is disabled.")
      end
    end
  end
end
