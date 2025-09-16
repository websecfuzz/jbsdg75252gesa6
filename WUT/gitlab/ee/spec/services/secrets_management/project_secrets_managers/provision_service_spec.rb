# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProjectSecretsManagers::ProvisionService, :gitlab_secrets_manager, feature_category: :secrets_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  let(:secrets_manager) { create(:project_secrets_manager, project: project) }
  let(:service) { described_class.new(secrets_manager, user) }

  subject(:result) { service.execute }

  describe '#execute' do
    it 'enables the secret engine for the project and activates the secret manager', :aggregate_failures do
      expect(result).to be_success

      expect(secrets_manager.reload).to be_active

      expect_kv_secret_engine_to_be_mounted(secrets_manager.ci_secrets_mount_path)
      expect_jwt_auth_engine_to_be_mounted(secrets_manager.ci_auth_mount)
    end

    it 'configures JWT role with correct settings', :aggregate_failures do
      result

      jwt_role = secrets_manager_client.read_jwt_role(secrets_manager.ci_auth_mount, secrets_manager.ci_auth_role)

      expect(jwt_role).to be_present
      expect(jwt_role["token_policies"]).to include(*secrets_manager.ci_auth_literal_policies)
      expect(jwt_role["bound_claims"]["project_id"].to_i).to eq(project.id)
      expect(jwt_role["bound_audiences"]).to include(SecretsManagement::ProjectSecretsManager.server_url)
      expect(jwt_role["user_claim"]).to eq("project_id")
      expect(jwt_role["token_type"]).to eq("service")

      # Verify all expected policies are configured
      secrets_manager.ci_auth_literal_policies.each do |policy|
        expect(jwt_role["token_policies"]).to include(policy)
      end
    end

    context 'when the secrets manager is already active' do
      before do
        secrets_manager.activate!
      end

      it 'completes successfully without changing the status' do
        expect(result).to be_success
        expect(secrets_manager.reload).to be_active

        # Verify the engines are still mounted
        expect_kv_secret_engine_to_be_mounted(secrets_manager.ci_secrets_mount_path)
        expect_jwt_auth_engine_to_be_mounted(secrets_manager.ci_auth_mount)
      end
    end

    context 'when the secrets engine has already been enabled' do
      before do
        clean_all_kv_secrets_engines
        clean_all_pipeline_jwt_engines

        secrets_manager_client.enable_secrets_engine(
          secrets_manager.ci_secrets_mount_path,
          described_class::SECRETS_ENGINE_TYPE
        )
      end

      it 'still activates the secrets manager and creates the JWT' do
        expect(result).to be_success

        expect(secrets_manager.reload).to be_active

        expect_kv_secret_engine_to_be_mounted(secrets_manager.ci_secrets_mount_path)
        expect_jwt_auth_engine_to_be_mounted(secrets_manager.ci_auth_mount)
      end
    end

    context 'when the auth engine has already been enabled' do
      before do
        clean_all_kv_secrets_engines
        clean_all_pipeline_jwt_engines

        secrets_manager_client.enable_auth_engine(secrets_manager.ci_auth_mount, secrets_manager.ci_auth_type)
      end

      it 'still activates the secrets manager and creates the KV mount' do
        expect(result).to be_success

        expect(secrets_manager.reload).to be_active

        expect_kv_secret_engine_to_be_mounted(secrets_manager.ci_secrets_mount_path)
        expect_jwt_auth_engine_to_be_mounted(secrets_manager.ci_auth_mount)

        expect { secrets_manager_client.read_jwt_role(secrets_manager.ci_auth_mount, secrets_manager.ci_auth_role) }
          .not_to raise_error
      end
    end

    context 'when both the secrets engine and auth engine already exist' do
      before do
        clean_all_kv_secrets_engines
        clean_all_pipeline_jwt_engines

        secrets_manager_client.enable_secrets_engine(
          secrets_manager.ci_secrets_mount_path,
          described_class::SECRETS_ENGINE_TYPE
        )

        secrets_manager_client.enable_auth_engine(
          secrets_manager.ci_auth_mount,
          secrets_manager.ci_auth_type
        )
      end

      it 'activates the secrets manager and configures JWT role' do
        expect(result).to be_success
        expect(secrets_manager.reload).to be_active

        # Check that JWT role was properly configured
        jwt_role = secrets_manager_client.read_jwt_role(secrets_manager.ci_auth_mount, secrets_manager.ci_auth_role)
        expect(jwt_role).to be_present

        # Verify the specifics of JWT role configuration
        expect(jwt_role["token_policies"]).to include(*secrets_manager.ci_auth_literal_policies)

        # Make sure bound_claims and other important properties are set
        expect(jwt_role["bound_claims"]["project_id"].to_i).to eq(project.id)
        expect(jwt_role["user_claim"]).to eq("project_id")
      end
    end
  end
end
