# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProjectSecrets::DeleteService, :gitlab_secrets_manager, feature_category: :secrets_management do
  include SecretsManagement::GitlabSecretsManagerHelpers

  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:user) { create(:user, owner_of: project) }

  let(:service) { described_class.new(project, user) }
  let(:name) { 'TEST_SECRET' }
  let(:description) { 'test description' }
  let(:value) { 'the-secret-value' }
  let(:branch) { 'main' }
  let(:environment) { 'prod' }

  describe '#execute', :aggregate_failures do
    context 'when the project secrets manager is active' do
      let_it_be_with_reload(:secrets_manager) { create(:project_secrets_manager, project: project) }

      subject(:result) { service.execute(name) }

      before do
        provision_project_secrets_manager(secrets_manager, user)

        # Create a secret to delete
        create_project_secret(
          user: user,
          project: project,
          name: name,
          value: value,
          branch: branch,
          environment: environment,
          description: description
        )
      end

      context 'when the secret exists' do
        it 'deletes a project secret and cleans up everything' do
          expect(result).to be_success
          expect(result.payload[:project_secret]).to be_present
          expect(result.payload[:project_secret].name).to eq(name)
          expect(result.payload[:project_secret].description).to eq(description)
          expect(result.payload[:project_secret].branch).to eq(branch)
          expect(result.payload[:project_secret].environment).to eq(environment)

          expect_kv_secret_not_to_exist(
            project.secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name)
          )

          # Since this was the only secret, the policy should be completely deleted
          policy_name = project.secrets_manager.ci_policy_name(environment, branch)
          expect_policy_not_to_exist(policy_name)

          expect_project_secret_not_to_exist(project, name, user)
        end
      end

      context 'when multiple secrets share the same policy' do
        let(:second_secret_name) { 'SECOND_SECRET' }
        let(:second_secret_environment) { environment }
        let(:second_secret_branch) { branch }

        before do
          # Create a second secret with the same environment and branch
          # This will share the same policy as the first secret
          create_project_secret(
            user: user,
            project: project,
            name: second_secret_name,
            value: "second-value",
            branch: second_secret_branch,
            environment: second_secret_environment,
            description: "Second secret"
          )
        end

        it 'deletes the secret but preserves the policy with remaining secret paths' do
          expect(result).to be_success

          expect_kv_secret_not_to_exist(
            project.secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name)
          )

          policy_name = project.secrets_manager.ci_policy_name(environment, branch)
          updated_policy = secrets_manager_client.get_policy(policy_name)
          expect(updated_policy).to be_present

          # First secret paths should be removed from the policy
          first_path = project.secrets_manager.ci_full_path(name)
          expect(updated_policy.paths.keys).not_to include(first_path)

          # Second secret should still have its paths and capabilities
          second_path = project.secrets_manager.ci_full_path(second_secret_name)
          expect(updated_policy.paths[second_path].capabilities).to include("read")

          expect_project_secret_not_to_exist(project, name, user)
        end

        context 'with wildcard patterns' do
          let(:wildcard_branch) { 'feature/*' }
          let(:wildcard_environment) { 'staging-*' }
          let(:environment) { wildcard_environment }
          let(:branch) { wildcard_branch }

          let(:glob_policies) do
            project.secrets_manager.ci_auth_glob_policies(
              wildcard_environment,
              wildcard_branch
            )
          end

          context 'when no other secrets share the same wildcard patterns' do
            let(:second_secret_branch) { 'dev/*' }
            let(:second_secret_environment) { 'prod-*' }

            it 'deletes the secret and removes glob policies from the JWT role' do
              # Get JWT role before deletion
              role_before = secrets_manager_client.read_jwt_role(
                project.secrets_manager.ci_auth_mount,
                project.secrets_manager.ci_auth_role
              )

              # Verify glob policies exist before deletion
              expect(role_before["token_policies"] & glob_policies).to match_array(glob_policies)

              # Delete the secret
              wildcard_result = described_class.new(project, user).execute(name)
              expect(wildcard_result).to be_success

              # Verify secret is deleted
              expect_kv_secret_not_to_exist(
                project.secrets_manager.ci_secrets_mount_path,
                secrets_manager.ci_data_path(name)
              )

              # Verify glob policies are removed from JWT role
              updated_role = secrets_manager_client.read_jwt_role(
                project.secrets_manager.ci_auth_mount,
                project.secrets_manager.ci_auth_role
              )

              expect(updated_role["token_policies"]).not_to include(*glob_policies)

              # Verify policy is also deleted
              policy_name = project.secrets_manager.ci_policy_name(wildcard_environment, wildcard_branch)
              expect_policy_not_to_exist(policy_name)
            end
          end

          context 'when other secrets share the same wildcard patterns' do
            let(:second_secret_branch) { wildcard_branch }
            let(:second_secret_environment) { wildcard_environment }

            it 'preserves the glob policies needed by other secrets when deleting first secret' do
              # Delete the first wildcard secret
              first_delete_result = described_class.new(project, user).execute(name)
              expect(first_delete_result).to be_success

              # Verify secret is deleted
              expect_kv_secret_not_to_exist(
                project.secrets_manager.ci_secrets_mount_path,
                secrets_manager.ci_data_path(name)
              )

              # Get the updated JWT role
              updated_role = secrets_manager_client.read_jwt_role(
                project.secrets_manager.ci_auth_mount,
                project.secrets_manager.ci_auth_role
              )

              # The glob policies should still be present because second_wildcard_secret needs them
              expect(updated_role["token_policies"]).to include(*glob_policies)

              # Verify the second secret is still accessible
              read_service = SecretsManagement::ProjectSecrets::ReadService.new(project, user)
              read_result = read_service.execute(second_secret_name)
              expect(read_result).to be_success
              expect(read_result.payload[:project_secret].name).to eq(second_secret_name)

              # Delete the second wildcard secret
              second_delete_result = described_class.new(project, user).execute(second_secret_name)
              expect(second_delete_result).to be_success

              # After deleting both secrets, the glob policies should be removed
              final_role = secrets_manager_client.read_jwt_role(
                project.secrets_manager.ci_auth_mount,
                project.secrets_manager.ci_auth_role
              )

              expect(final_role["token_policies"]).not_to include(*glob_policies)
            end
          end

          context 'with overlapping wildcard patterns' do
            # Second secret uses the same environment wildcard but a specific branch
            let(:second_secret_branch) { 'main' } # Not a wildcard
            let(:second_secret_environment) { 'staging-*' }

            # Explicitly get all glob policies for first secret
            let(:first_secret_glob_policies) do
              project.secrets_manager.ci_auth_glob_policies(wildcard_environment, wildcard_branch)
            end

            # Explicitly get all glob policies for second secret
            let(:second_secret_glob_policies) do
              project.secrets_manager.ci_auth_glob_policies(second_secret_environment, second_secret_branch)
            end

            it 'correctly handles overlapping glob policies' do
              role_before = secrets_manager_client.read_jwt_role(
                project.secrets_manager.ci_auth_mount,
                project.secrets_manager.ci_auth_role
              )

              # Verify JWT role has all needed policies before deletion
              expect(role_before["token_policies"]).to include(*first_secret_glob_policies)
              expect(role_before["token_policies"]).to include(*second_secret_glob_policies)

              current_policies = role_before["token_policies"]

              policies_to_remove = first_secret_glob_policies - second_secret_glob_policies

              # Calculate expected policies after deletion
              expected_policies = current_policies - policies_to_remove

              # Delete the first secret
              result = service.execute(name)
              expect(result).to be_success

              # Get updated JWT role
              updated_role = secrets_manager_client.read_jwt_role(
                project.secrets_manager.ci_auth_mount,
                project.secrets_manager.ci_auth_role
              )

              # Verify updated policies match our expectation
              expect(updated_role["token_policies"]).to match_array(expected_policies)

              # The second secret should still be accessible
              read_service = SecretsManagement::ProjectSecrets::ReadService.new(project, user)
              read_result = read_service.execute(second_secret_name)
              expect(read_result).to be_success
            end
          end
        end
      end

      context 'when the secret does not exist' do
        let(:nonexistent_name) { 'NONEXISTENT_SECRET' }

        subject(:nonexistent_result) { service.execute(nonexistent_name) }

        it 'returns an error' do
          expect(nonexistent_result).not_to be_success
          expect(nonexistent_result.message).to eq('Project secret does not exist.')
        end
      end
    end

    context 'when user is a developer and no permissions' do
      let_it_be_with_reload(:secrets_manager) { create(:project_secrets_manager, project: project) }
      let(:user) { create(:user, developer_of: project) }

      subject(:result) { service.execute(name) }

      it 'returns an error' do
        provision_project_secrets_manager(secrets_manager, user)
        expect { result }
        .to raise_error(SecretsManagement::SecretsManagerClient::ApiError,
          "1 error occurred:\n\t* permission denied\n\n")
      end
    end

    context "when project's group has proper permissions" do
      let(:group) { create(:group) }
      let(:project) { create(:project, group: group) }
      let(:secrets_manager) { create(:project_secrets_manager, project: project) }

      let(:user) { create(:user, developer_of: project) }

      subject(:result) { service.execute(name) }

      before do
        provision_project_secrets_manager(secrets_manager, user)
        update_secret_permission(
          user: user, project: project, permissions: %w[
            create update delete read
          ], principal: { id: group.id, type: 'Group' }
        )

        # Create a secret to delete
        create_project_secret(
          user: user,
          project: project,
          name: name,
          value: value,
          branch: branch,
          environment: environment,
          description: description
        )
      end

      it 'returns success' do
        expect(result).to be_success
      end
    end

    context 'when the project secrets manager is not active' do
      subject(:result) { service.execute(name) }

      it 'returns an error' do
        expect(result).to be_error
        expect(result.message).to eq('Project secrets manager is not active')
      end
    end
  end
end
