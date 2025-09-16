# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Delete Secret Permission', :gitlab_secrets_manager, feature_category: :secrets_management do
  include GraphqlHelpers

  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:mutation_name) { :secret_permission_delete }
  let(:secrets_manager) { create(:project_secrets_manager, project: project) }

  let(:params) do
    {
      projectPath: project.full_path,
      principal: {
        id: principal[:id],
        type: principal[:type]
      }
    }
  end

  let(:mutation) { graphql_mutation(mutation_name, params) }
  let(:mutation_response) { graphql_mutation_response(mutation_name) }

  subject(:delete_mutation) { post_graphql_mutation(mutation, current_user: current_user) }

  before do
    provision_project_secrets_manager(secrets_manager, current_user)
  end

  context 'when current user is not part of the project' do
    let_it_be(:user) { create(:user) }
    let(:principal) { { id: user.id, type: 'USER' } }

    it_behaves_like 'a mutation on an unauthorized resource'
  end

  context 'when current user is not the project owner' do
    let_it_be(:user) { create(:user) }
    let(:principal) { { id: user.id, type: 'USER' } }

    before_all do
      project.add_maintainer(current_user)
    end

    it_behaves_like 'a mutation on an unauthorized resource'
  end

  context 'when user has permissions' do
    let_it_be(:user) { create(:user) }
    let(:principal) { { id: user.id, type: 'USER' } }

    before_all do
      project.add_maintainer(user)
      project.add_owner(current_user)
    end

    it 'deletes the secret permission', :aggregate_failures do
      delete_mutation
      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['errors']).to be_empty
    end
  end

  context 'and service results to a failure' do
    let_it_be(:user) { create(:user) }
    let(:principal) { { id: user.id, type: 'USER' } }

    before_all do
      project.add_owner(current_user)
    end
    it 'returns the service error' do
      expect_next_instance_of(SecretsManagement::Permissions::DeleteService) do |service|
        secret_permission = SecretsManagement::SecretPermission.new
        secret_permission.errors.add(:base, 'some error')

        result = ServiceResponse.error(message: 'some error', payload: { secret_permission: secret_permission })
        expect(service).to receive(:execute).and_return(result)
      end

      delete_mutation

      expect(mutation_response['errors']).to include('some error')
    end
  end

  context 'when the user is removed from the project' do
    let_it_be(:user) { create(:user) }
    let(:principal) { { id: user.id, type: 'USER' } }

    before_all do
      project.add_owner(current_user)
    end

    it 'the current user is able to delete the existing secret permission', :aggregate_failures do
      delete_mutation
      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['errors']).to be_empty
    end
  end

  context 'and secrets_manager feature flag is disabled' do
    let_it_be(:user) { create(:user) }
    let(:principal) { { id: user.id, type: 'USER' } }
    let(:err_message) do
      "`secrets_manager` feature flag is disabled."
    end

    before_all do
      project.add_owner(current_user)
    end

    it 'returns an error' do
      stub_feature_flags(secrets_manager: false)

      delete_mutation

      expect_graphql_errors_to_include(err_message)
    end
  end
end
