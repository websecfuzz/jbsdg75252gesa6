# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::Permissions::DeleteService, :gitlab_secrets_manager, feature_category: :secrets_management do
  include SecretsManagement::GitlabSecretsManagerHelpers

  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:secrets_manager) { create(:project_secrets_manager, project: project) }

  let(:service) { described_class.new(project, user) }
  let(:principal_id) { user.id }
  let(:principal_type) { 'User' }

  before_all do
    project.add_owner(user)
  end

  subject(:result) { service.execute(principal: { id: principal_id, type: principal_type }) }

  describe '#execute' do
    context 'when the project secrets manager is active' do
      before do
        provision_project_secrets_manager(secrets_manager, user)
      end

      context 'when the permission exists' do
        it 'deletes a secret permission and cleans up everything' do
          expect(result).to be_success
        end
      end

      context 'when principal-id format is invalid' do
        let(:principal_id) { '35sds' }

        it 'returns an error' do
          expect(result).to be_error
          expect(result.message).to eq('Invalid principal')
        end
      end

      context 'when principal-type format is invalid' do
        let(:principal_type) { 'TestModel' }

        it 'returns an error' do
          expect(result).to be_error
          expect(result.message).to eq('Invalid principal')
        end
      end
    end

    context 'when the project secrets manager is not active' do
      it 'returns an error' do
        expect(result).to be_error
        expect(result.message).to eq('Project secrets manager is not active')
      end
    end
  end

  describe '#execute with API errors' do
    context 'when a connection error occurs' do
      let(:error_message) { 'Failed to connect to secrets manager' }

      before do
        provision_project_secrets_manager(secrets_manager, user)
      end

      it 'returns an error response with the connection error message' do
        client = SecretsManagement::SecretsManagerClient
        allow(service).to receive(:secrets_manager_client).and_return(instance_double(client))
        allow(service.secrets_manager_client).to receive(:delete_policy)
          .and_raise(SecretsManagement::SecretsManagerClient::ConnectionError.new(error_message))

        result = service.execute(principal: { id: principal_id, type: principal_type })

        expect(result).to be_error
        expect(result.message).to eq("Failed to delete permission: #{error_message}")
        expect(result.payload[:secret_permission]).to be_nil
      end
    end
  end
end
