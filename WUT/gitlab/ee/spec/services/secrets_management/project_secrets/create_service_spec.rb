# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProjectSecrets::CreateService, :gitlab_secrets_manager, feature_category: :secrets_management do
  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:user) { create(:user, owner_of: project) }

  let(:service) { described_class.new(project, user) }
  let(:name) { 'TEST_SECRET' }
  let(:description) { 'test description' }
  let(:value) { 'the-secret-value' }
  let(:branch) { 'main' }
  let(:environment) { 'prod' }

  subject(:result) do
    service.execute(name: name, description: description, value: value, branch: branch, environment: environment)
  end

  describe '#execute', :aggregate_failures do
    context 'when the project secrets manager is active' do
      let_it_be_with_reload(:secrets_manager) { create(:project_secrets_manager, project: project) }

      before do
        provision_project_secrets_manager(secrets_manager, user)
      end

      it 'creates a project secret' do
        expect(result).to be_success

        secret = result.payload[:project_secret]
        expect(secret).to be_present
        expect(secret.name).to eq(name)
        expect(secret.description).to eq(description)
        expect(secret.project).to eq(project)
        expect(secret.metadata_version).to eq(1)

        expect_kv_secret_to_have_value(
          project.secrets_manager.ci_secrets_mount_path,
          secrets_manager.ci_data_path(name),
          value
        )
        expect_kv_secret_to_have_custom_metadata(
          project.secrets_manager.ci_secrets_mount_path,
          secrets_manager.ci_data_path(name),
          "description" => description,
          "environment" => environment,
          "branch" => branch
        )

        # Validate correct policy has path.
        expected_policy_name = project.secrets_manager.ci_policy_name_combined(environment, branch)
        actual_policy = secrets_manager_client.get_policy(expected_policy_name)
        expect(actual_policy).not_to be_nil

        expected_path = project.secrets_manager.ci_full_path(name)
        expect(actual_policy.paths).to include(expected_path)
        expect(actual_policy.paths[expected_path].capabilities).to eq(Set.new(["read"]))

        expected_path = project.secrets_manager.ci_metadata_full_path(name)
        expect(actual_policy.paths).to include(expected_path)
        expect(actual_policy.paths[expected_path].capabilities).to eq(Set.new(["read"]))
      end

      context 'when using any environment' do
        let(:environment) { '*' }

        it 'create the correct policy and custom metadata' do
          expect(result).to be_success

          # Validate correct policy has path.
          expected_policy_name = project.secrets_manager.ci_policy_name_branch(branch)
          actual_policy = secrets_manager_client.get_policy(expected_policy_name)
          expect(actual_policy).not_to be_nil

          expected_path = project.secrets_manager.ci_full_path(name)
          expect(actual_policy.paths).to include(expected_path)
          expect(actual_policy.paths[expected_path].capabilities).to eq(Set.new(["read"]))

          expected_path = project.secrets_manager.ci_metadata_full_path(name)
          expect(actual_policy.paths).to include(expected_path)
          expect(actual_policy.paths[expected_path].capabilities).to eq(Set.new(["read"]))

          expect_kv_secret_to_have_custom_metadata(
            project.secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            "environment" => environment
          )
        end
      end

      context 'when using any branch' do
        let(:branch) { '*' }

        it 'create the correct policy and custom metadata' do
          expect(result).to be_success

          # Validate correct policy has path.
          expected_policy_name = project.secrets_manager.ci_policy_name_env(environment)
          actual_policy = secrets_manager_client.get_policy(expected_policy_name)
          expect(actual_policy).not_to be_nil

          expected_path = project.secrets_manager.ci_full_path(name)
          expect(actual_policy.paths).to include(expected_path)
          expect(actual_policy.paths[expected_path].capabilities).to eq(Set.new(["read"]))

          expected_path = project.secrets_manager.ci_metadata_full_path(name)
          expect(actual_policy.paths).to include(expected_path)
          expect(actual_policy.paths[expected_path].capabilities).to eq(Set.new(["read"]))

          expect_kv_secret_to_have_custom_metadata(
            project.secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            "branch" => branch
          )
        end

        context 'and any environmnet' do
          let(:environment) { '*' }

          it 'create the correct policy and custom metadata' do
            expect(result).to be_success

            # Validate correct policy has path.
            expected_policy_name = project.secrets_manager.ci_policy_name_global
            actual_policy = secrets_manager_client.get_policy(expected_policy_name)
            expect(actual_policy).not_to be_nil

            expected_path = project.secrets_manager.ci_full_path(name)
            expect(actual_policy.paths).to include(expected_path)
            expect(actual_policy.paths[expected_path].capabilities).to eq(Set.new(["read"]))

            expected_path = project.secrets_manager.ci_metadata_full_path(name)
            expect(actual_policy.paths).to include(expected_path)
            expect(actual_policy.paths[expected_path].capabilities).to eq(Set.new(["read"]))

            expect_kv_secret_to_have_custom_metadata(
              project.secrets_manager.ci_secrets_mount_path,
              secrets_manager.ci_data_path(name),
              "environment" => environment,
              "branch" => branch
            )
          end
        end

        context 'when not providing an environment' do
          let(:environment) { '' }

          it 'fails' do
            expect(result).to be_error
            expect(result.message).to eq('Environment can\'t be blank')
          end
        end

        context 'when not providing a branch' do
          let(:branch) { '' }

          it 'fails' do
            expect(result).to be_error
            expect(result.message).to eq('Branch can\'t be blank')
          end
        end
      end

      context 'when the secret already exists' do
        before do
          described_class.new(project, user).execute(name: name, value: value, environment: environment, branch: branch)
        end

        it 'fails' do
          expect(result).to be_error
          expect(result.message).to eq('Project secret already exists.')
        end
      end
    end

    context 'when user is a developer and no permissions' do
      let_it_be_with_reload(:secrets_manager) { create(:project_secrets_manager, project: project) }
      let(:user) { create(:user, developer_of: project) }

      subject(:result) do
        service.execute(name: name, description: description, value: value, branch: branch, environment: environment)
      end

      it 'returns an error' do
        provision_project_secrets_manager(secrets_manager, user)
        expect { result }
        .to raise_error(SecretsManagement::SecretsManagerClient::ApiError,
          "1 error occurred:\n\t* permission denied\n\n")
      end
    end

    context 'when user role - developer has proper permissions' do
      let_it_be_with_reload(:secrets_manager) { create(:project_secrets_manager, project: project) }
      let(:user) { create(:user, developer_of: project) }

      subject(:result) do
        service.execute(name: name, description: description, value: value, branch: branch, environment: environment)
      end

      before do
        provision_project_secrets_manager(secrets_manager, user)
        update_secret_permission(
          user: user, project: project, permissions: %w[create read update], principal: {
            id: Gitlab::Access.sym_options[:developer], type: 'Role'
          }
        )
      end

      it 'returns success' do
        expect(result).to be_success
        expect(result.payload[:project_secret]).to be_present
      end
    end

    context 'when user has proper permissions' do
      let_it_be_with_reload(:secrets_manager) { create(:project_secrets_manager, project: project) }
      let(:user) { create(:user, developer_of: project) }

      subject(:result) do
        service.execute(name: name, description: description, value: value, branch: branch, environment: environment)
      end

      before do
        provision_project_secrets_manager(secrets_manager, user)
        update_secret_permission(
          user: user, project: project, permissions: %w[create read update], principal: {
            id: user.id, type: 'User'
          }
        )
      end

      it 'returns success' do
        expect(result).to be_success
        expect(result.payload[:project_secret]).to be_present
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
end
