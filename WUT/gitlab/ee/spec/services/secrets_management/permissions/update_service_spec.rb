# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'

RSpec.describe SecretsManagement::Permissions::UpdateService, :gitlab_secrets_manager, feature_category: :secrets_management do
  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  let(:service) { described_class.new(project, user) }
  let(:principal_id) { user.id }
  let(:principal_type) { 'User' }
  let(:permissions) { %w[create update read] }
  let(:expired_at) { 1.week.from_now.to_date.iso8601 }

  before_all do
    project.add_owner(user)
  end

  subject(:result) do
    service.execute(principal_id: principal_id, principal_type: principal_type, permissions: permissions,
      expired_at: expired_at)
  end

  describe '#execute' do
    context 'when the project secrets manager is active' do
      let_it_be_with_reload(:secrets_manager) { create(:project_secrets_manager, project: project) }

      before do
        provision_project_secrets_manager(secrets_manager, user)
      end

      context 'when the user is part of the project' do
        it 'updates a secret permission' do
          expect(result).to be_success

          secret_permission = result.payload[:secret_permission]
          expect(secret_permission).to be_present
          expect(secret_permission.principal_id).to eq(user.id)
          expect(secret_permission.principal_type).to eq('User')
          expect(secret_permission.permissions).to eq(permissions)
          expect(secret_permission.expired_at).to eq(expired_at)
        end
      end

      context 'when the user is not part of the project' do
        let(:new_user) { create(:user) }
        let(:principal_id) { new_user.id }
        let(:principal_type) { 'User' }

        it 'returns an error' do
          expect(result).to be_error
          expect(result.message).to eq('Principal User is not a member of the Project')
        end
      end

      context 'when the principal-type is invalid' do
        let(:principal_type) { 'TestModel' }

        it 'returns an error' do
          expect(result).to be_error
          expect(result.message).to eq('Principal type must be one of: User, Role, Group, MemberRole')
        end
      end

      context 'when the principal-ID is invalid' do
        let(:principal_id) { 'delete' }

        it 'returns an error' do
          expect(result).to be_error
          expect(result.message).to eq('Principal User does not exist')
        end
      end
    end

    context 'when the project secrets manager is not active' do
      let_it_be_with_reload(:secrets_manager) { create(:project_secrets_manager, project: project) }

      it 'fails' do
        expect(result).to be_error
        expect(result.message).to eq('Project secrets manager is not active.')
      end
    end

    context 'when the project has not enabled secrets manager at all' do
      it 'fails' do
        expect(result).to be_error
        expect(result.message).to eq('Project secrets manager is not active.')
      end
    end
  end

  describe '#execute for Api errors' do
    context 'when a check-and-set parameter error occurs' do
      let_it_be_with_reload(:secrets_manager) { create(:project_secrets_manager, project: project) }
      let(:err) { 'check-and-set parameter did not match the current version' }

      before do
        provision_project_secrets_manager(secrets_manager, user)

        stub_request(:post, %r{.*/v1/sys/policies/acl/.*})
        .to_return(
          status: 400,
          body: { errors: [err] }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
      end

      it 'returns an error response with the error message' do
        result = service.execute(
          principal_id: principal_id,
          principal_type: principal_type,
          permissions: permissions,
          expired_at: expired_at
        )

        expect(result).to be_error
        expect(result.message).to include("Failed to save secret_permission")
        expect(result.payload[:secret_permission].errors[:base]).to include("Failed to save secret_permission: #{err}")
      end
    end
  end
end
