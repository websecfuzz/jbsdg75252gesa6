# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProjectSecrets::UpdateService, :gitlab_secrets_manager, feature_category: :secrets_management do
  include SecretsManagement::GitlabSecretsManagerHelpers

  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:user) { create(:user, owner_of: project) }
  let_it_be_with_reload(:secrets_manager) { create(:project_secrets_manager, project: project) }

  let(:service) { described_class.new(project, user) }
  let(:name) { 'TEST_SECRET' }
  let(:original_description) { 'test description' }
  let(:original_value) { 'the-secret-value' }
  let(:original_branch) { 'main' }
  let(:original_environment) { 'prod' }

  let(:new_description) { 'updated description' }
  let(:new_value) { 'updated-secret-value' }
  let(:new_branch) { 'feature' }
  let(:new_environment) { 'staging' }

  let(:description) { nil }
  let(:value) { nil }
  let(:branch) { nil }
  let(:environment) { nil }
  let(:metadata_cas) { 1 }

  describe '#execute', :aggregate_failures do
    context 'when the project secrets manager is active' do
      subject(:result) do
        service.execute(
          name: name,
          description: description,
          value: value,
          branch: branch,
          environment: environment,
          metadata_cas: metadata_cas
        )
      end

      before do
        provision_project_secrets_manager(secrets_manager, user)

        # Create a secret to update
        create_project_secret(
          user: user,
          project: project,
          name: name,
          value: original_value,
          branch: original_branch,
          environment: original_environment,
          description: original_description
        )
      end

      context 'when updating description only' do
        let(:description) { new_description }

        it 'updates the description only' do
          expect(result).to be_success
          expect(result.payload[:project_secret].description).to eq(new_description)
          expect(result.payload[:project_secret].metadata_version).to eq(2)

          # Verify metadata was updated
          expect_kv_secret_to_have_custom_metadata(
            project.secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            "description" => new_description
          )

          # Verify value is unchanged
          expect_kv_secret_to_have_value(
            project.secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            original_value
          )

          # Verify policies are unchanged
          policy_name = project.secrets_manager.ci_policy_name(original_environment, original_branch)
          policy = secrets_manager_client.get_policy(policy_name)
          expect(policy.paths).to include(project.secrets_manager.ci_full_path(name))
        end
      end

      context 'when updating value only' do
        let(:value) { new_value }

        it 'updates the value' do
          expect(result).to be_success
          expect(result.payload[:project_secret].metadata_version).to eq(2)

          # Verify the value was updated
          expect_kv_secret_to_have_value(
            project.secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            new_value
          )

          # Verify metadata is unchanged
          expect_kv_secret_to_have_custom_metadata(
            project.secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            "description" => original_description,
            "environment" => original_environment,
            "branch" => original_branch
          )
        end
      end

      context 'when updating environment' do
        let(:environment) { new_environment }

        it 'updates the environment and policies' do
          expect(result).to be_success
          expect(result.payload[:project_secret].environment).to eq(new_environment)
          expect(result.payload[:project_secret].metadata_version).to eq(2)

          # Verify metadata was updated
          expect_kv_secret_to_have_custom_metadata(
            project.secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            "environment" => new_environment
          )

          # Verify old policy no longer contains the secret
          old_policy_name = project.secrets_manager.ci_policy_name(original_environment, original_branch)
          old_policy = secrets_manager_client.get_policy(old_policy_name)

          expect(old_policy.paths).not_to include(project.secrets_manager.ci_full_path(name))

          # Verify new policy contains the secret
          new_policy_name = project.secrets_manager.ci_policy_name(new_environment, original_branch)
          new_policy = secrets_manager_client.get_policy(new_policy_name)

          expect(new_policy.paths).to include(project.secrets_manager.ci_full_path(name))
        end
      end

      context 'when the original policy has no other secrets' do
        let(:environment) { new_environment }

        it 'removes the old policy entirely' do
          expect(result).to be_success

          # Verify the old policy has been completely deleted or is empty
          old_policy_name = project.secrets_manager.ci_policy_name(original_environment, original_branch)
          old_policy = secrets_manager_client.get_policy(old_policy_name)

          expect(old_policy.paths).to be_empty
        end
      end

      context 'when updating branch' do
        let(:branch) { new_branch }

        it 'updates the branch and policies' do
          expect(result).to be_success
          expect(result.payload[:project_secret].branch).to eq(new_branch)
          expect(result.payload[:project_secret].metadata_version).to eq(2)

          # Verify metadata was updated
          expect_kv_secret_to_have_custom_metadata(
            project.secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            "branch" => new_branch
          )

          # Verify old policy no longer contains the secret
          old_policy_name = project.secrets_manager.ci_policy_name(original_environment, original_branch)
          old_policy = secrets_manager_client.get_policy(old_policy_name)

          expect(old_policy.paths).not_to include(project.secrets_manager.ci_full_path(name))

          # Verify new policy contains the secret
          new_policy_name = project.secrets_manager.ci_policy_name(original_environment, new_branch)
          new_policy = secrets_manager_client.get_policy(new_policy_name)

          expect(new_policy.paths).to include(project.secrets_manager.ci_full_path(name))
        end
      end

      context 'when updating everything' do
        let(:description) { new_description }
        let(:value) { new_value }
        let(:branch) { new_branch }
        let(:environment) { new_environment }

        it 'updates all fields and policies' do
          expect(result).to be_success
          expect(result.payload[:project_secret].description).to eq(new_description)
          expect(result.payload[:project_secret].branch).to eq(new_branch)
          expect(result.payload[:project_secret].environment).to eq(new_environment)
          expect(result.payload[:project_secret].metadata_version).to eq(2)

          # Verify value was updated
          expect_kv_secret_to_have_value(
            project.secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            new_value
          )

          # Verify metadata was updated
          expect_kv_secret_to_have_custom_metadata(
            project.secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            "description" => new_description,
            "environment" => new_environment,
            "branch" => new_branch
          )

          # Verify old policy no longer contains the secret
          old_policy_name = project.secrets_manager.ci_policy_name(original_environment, original_branch)
          old_policy = secrets_manager_client.get_policy(old_policy_name)

          expect(old_policy.paths).not_to include(project.secrets_manager.ci_full_path(name))

          # Verify new policy contains the secret
          new_policy_name = project.secrets_manager.ci_policy_name(new_environment, new_branch)
          new_policy = secrets_manager_client.get_policy(new_policy_name)

          expect(new_policy.paths).to include(project.secrets_manager.ci_full_path(name))
        end
      end

      context 'when updating environment or branch with wildcard patterns' do
        context 'when updating from non-wildcard to wildcard' do
          let(:branch) { 'feature/*' }
          let(:environment) { 'staging-*' }

          it 'updates environment and branch with wildcards and configures JWT role' do
            # Get glob policies for the wildcard patterns
            glob_policies = project.secrets_manager.ci_auth_glob_policies(environment, branch)

            # Run the update
            expect(result).to be_success

            # Check JWT role after update
            role_after = secrets_manager_client.read_jwt_role(
              project.secrets_manager.ci_auth_mount,
              project.secrets_manager.ci_auth_role
            )

            # Verify glob policies are present after update
            expect(role_after["token_policies"] & glob_policies).to match_array(glob_policies)

            # Verify the secret is in the right policy
            new_policy_name = project.secrets_manager.ci_policy_name(environment, branch)
            new_policy = secrets_manager_client.get_policy(new_policy_name)

            expect(new_policy.paths).to include(project.secrets_manager.ci_full_path(name))
          end
        end

        context 'when updating from wildcard to non-wildcard' do
          let(:original_branch) { 'feature/*' }
          let(:original_environment) { 'staging-*' }
          let(:environment) { 'production' }
          let(:branch) { 'master' }

          it 'removes wildcards from JWT role when not needed' do
            old_glob_policies = project.secrets_manager.ci_auth_glob_policies(original_environment, original_branch)

            # Check JWT role before update
            role_before = secrets_manager_client.read_jwt_role(
              project.secrets_manager.ci_auth_mount,
              project.secrets_manager.ci_auth_role
            )

            # Verify glob policies exist before update
            expect(role_before["token_policies"] & old_glob_policies).to match_array(old_glob_policies)

            # Run the update to non-wildcards
            expect(result).to be_success

            # Check JWT role after update
            role_after = secrets_manager_client.read_jwt_role(
              project.secrets_manager.ci_auth_mount,
              project.secrets_manager.ci_auth_role
            )

            # Verify glob policies were removed
            expect(role_after["token_policies"]).not_to include(*old_glob_policies)
          end

          context 'and other secrets are under the previous wildcards' do
            let(:second_secret_name) { 'SECOND_SECRET' }

            before do
              create_project_secret(
                user: user,
                project: project,
                name: second_secret_name,
                value: 'second-value',
                branch: original_branch,
                environment: original_environment,
                description: 'Second secret'
              )
            end

            it 'preserves the wildcards in JWT role needed by other secrets' do
              # Get glob policies for the second secret's wildcards
              second_glob_policies = project.secrets_manager.ci_auth_glob_policies('staging-*', 'feature/*')

              # Run the update (changing from non-wildcard to non-wildcard, but other secret has wildcards)
              expect(result).to be_success

              # Check JWT role after update
              role_after = secrets_manager_client.read_jwt_role(
                project.secrets_manager.ci_auth_mount,
                project.secrets_manager.ci_auth_role
              )

              # Verify glob policies are still present for second secret
              second_glob_policies.each do |policy|
                expect(role_after["token_policies"]).to include(policy)
              end
            end
          end
        end
      end

      context 'when metadata_cas is not given' do
        let(:description) { new_description }
        let(:value) { new_value }
        let(:branch) { new_branch }
        let(:environment) { new_environment }
        let(:metadata_cas) { nil }

        it 'updates the secret' do
          expect(result).to be_success
          expect(result.payload[:project_secret].description).to eq(new_description)
          expect(result.payload[:project_secret].branch).to eq(new_branch)
          expect(result.payload[:project_secret].environment).to eq(new_environment)
          expect(result.payload[:project_secret].metadata_version).to be_nil

          # Verify value was updated
          expect_kv_secret_to_have_value(
            project.secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            new_value
          )

          # Verify metadata was updated
          expect_kv_secret_to_have_custom_metadata(
            project.secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            "description" => new_description,
            "environment" => new_environment,
            "branch" => new_branch
          )
        end
      end

      context 'when given metadata_cas does not match the metadata version' do
        let(:description) { new_description }
        let(:value) { new_value }
        let(:branch) { new_branch }
        let(:environment) { new_environment }
        let(:metadata_cas) { 2 }

        it 'returns an error' do
          expect(result).not_to be_success
          expect(result.message).to eq('metadata check-and-set parameter does not match the current version')

          # Verify value was not updated
          expect_kv_secret_to_have_value(
            project.secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            original_value
          )

          # Verify metadata is unchanged
          expect_kv_secret_to_have_custom_metadata(
            project.secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            "description" => original_description,
            "environment" => original_environment,
            "branch" => original_branch
          )
        end
      end

      context 'when the secret does not exist' do
        let(:nonexistent_name) { 'NONEXISTENT_SECRET' }

        subject(:nonexistent_result) do
          service.execute(name: nonexistent_name, metadata_cas: 1)
        end

        it 'returns an error' do
          expect(nonexistent_result).not_to be_success
          expect(nonexistent_result.message).to eq('Project secret does not exist.')
          expect(nonexistent_result.reason).to eq(:not_found)
        end
      end

      context 'with invalid inputs' do
        let(:branch) { '' } # Empty branch is invalid

        it 'returns an error' do
          expect(result).not_to be_success
          expect(result.message).to eq("Branch can't be blank")
        end
      end

      context 'when updating to share policy with another secret' do
        let(:second_secret_name) { 'SECOND_SECRET' }
        let(:environment) { 'shared-env' }  # Both secrets will share this environment
        let(:branch) { 'shared-branch' }    # Both secrets will share this branch

        before do
          # Create a second secret with the shared env/branch
          create_project_secret(
            user: user,
            project: project,
            name: second_secret_name,
            value: "second-value",
            branch: branch,
            environment: environment,
            description: "Second secret"
          )
        end

        it 'adds the secret to the shared policy' do
          expect(result).to be_success

          # Verify the shared policy has both secrets
          shared_policy_name = project.secrets_manager.ci_policy_name(environment, branch)
          shared_policy = secrets_manager_client.get_policy(shared_policy_name)

          expect(shared_policy.paths).to include(project.secrets_manager.ci_full_path(name))
          expect(shared_policy.paths).to include(project.secrets_manager.ci_full_path(second_secret_name))
        end
      end
    end

    context 'when user is a developer and no permissions' do
      let(:user) { create(:user, developer_of: project) }

      subject(:result) do
        service.execute(
          name: name,
          description: description,
          value: value,
          branch: branch,
          environment: environment,
          metadata_cas: metadata_cas
        )
      end

      it 'returns an error' do
        provision_project_secrets_manager(secrets_manager, user)
        expect { result }
        .to raise_error(SecretsManagement::SecretsManagerClient::ApiError,
          "1 error occurred:\n\t* permission denied\n\n")
      end
    end

    context 'when the project secrets manager is not active' do
      subject(:result) do
        service.execute(
          name: name,
          description: description,
          value: value,
          branch: branch,
          environment: environment,
          metadata_cas: metadata_cas
        )
      end

      it 'returns an error' do
        expect(result).to be_error
        expect(result.message).to eq('Project secrets manager is not active')
      end
    end
  end
end
