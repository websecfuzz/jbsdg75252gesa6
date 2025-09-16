# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Update Secret Permission', :gitlab_secrets_manager, feature_category: :secrets_management do
  include GraphqlHelpers

  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:mutation_name) { :secret_permission_update }
  let(:secrets_manager) { create(:project_secrets_manager, project: project) }

  let(:params) do
    {
      projectPath: project.full_path,
      principal: {
        id: principal[:id],
        type: principal[:type]
      },
      permissions: permissions,
      expiredAt: expired_at
    }
  end

  let(:mutation) { graphql_mutation(mutation_name, params) }
  let(:mutation_response) { graphql_mutation_response(mutation_name) }

  subject(:post_mutation) { post_graphql_mutation(mutation, current_user: current_user) }

  context 'when secret manager is enabled' do
    before do
      provision_project_secrets_manager(secrets_manager, current_user)
    end

    context 'when current user is not part of the project' do
      let_it_be(:user) { create(:user) }
      let(:principal) { { id: user.id, type: 'USER' } }
      let(:permissions) { %w[create update] }
      let(:expired_at) { 1.week.from_now.to_date.iso8601 }

      it_behaves_like 'a mutation on an unauthorized resource'
    end

    context 'when current user is not the project owner' do
      let_it_be(:user) { create(:user) }
      let(:principal) { { id: user.id, type: 'USER' } }
      let(:permissions) { %w[create update] }
      let(:expired_at) { 1.week.from_now.to_date.iso8601 }

      before_all do
        project.add_maintainer(current_user)
      end

      it_behaves_like 'a mutation on an unauthorized resource'
    end

    context 'when user has permissions' do
      let_it_be(:user) { create(:user) }
      let(:principal) { { id: user.id, type: 'USER' } }
      let(:permissions) { %w[create update read] }
      let(:expired_at) { 1.week.from_now.to_date.iso8601 }

      before_all do
        project.add_maintainer(user)
        project.add_owner(current_user)
      end

      it 'updates the secret permission' do
        post_mutation
        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to be_empty

        expect(mutation_response['secretPermission']).not_to be_nil
        expect(mutation_response['secretPermission']['principal']['id']).to eq(principal[:id].to_s)
        expect(mutation_response['secretPermission']['principal']['type']).to eq('User')
        expect(mutation_response['secretPermission']['permissions']).to eq(permissions.to_s)
        expect(mutation_response['secretPermission']['expiredAt']).to eq(expired_at)
      end
    end

    context 'and service results to a failure' do
      let_it_be(:user) { create(:user) }
      let(:principal) { { id: user.id, type: 'USER' } }
      let(:permissions) { %w[create update read] }
      let(:expired_at) { 1.week.from_now.to_date.iso8601 }

      before_all do
        project.add_owner(current_user)
      end

      before do
        allow_next_instance_of(SecretsManagement::Permissions::UpdateService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.error(message: 'some error'))
        end
      end

      it 'returns the service error' do
        expect_next_instance_of(SecretsManagement::Permissions::UpdateService) do |service|
          secret_permission = SecretsManagement::SecretPermission.new
          secret_permission.errors.add(:base, 'some error')

          result = ServiceResponse.error(message: 'some error', payload: { secret_permission: secret_permission })
          expect(service).to receive(:execute).and_return(result)
        end

        post_mutation

        expect(mutation_response['errors']).to include('some error')
      end

      it_behaves_like 'internal event not tracked'
    end
  end

  context 'and secrets_manager feature flag is disabled' do
    let_it_be(:user) { create(:user) }
    let(:principal) { { id: user.id, type: 'USER' } }
    let(:permissions) { %w[create update read] }
    let(:expired_at) { 1.week.from_now.to_date.iso8601 }
    let(:err_message) do
      "`secrets_manager` feature flag is disabled."
    end

    before_all do
      project.add_owner(current_user)
    end

    it 'returns an error' do
      stub_feature_flags(secrets_manager: false)

      post_mutation

      expect_graphql_errors_to_include(err_message)
    end
  end
end
