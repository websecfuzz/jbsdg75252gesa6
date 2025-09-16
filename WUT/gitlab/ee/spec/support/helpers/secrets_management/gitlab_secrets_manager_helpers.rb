# frozen_string_literal: true

module SecretsManagement
  module GitlabSecretsManagerHelpers
    def clean_all_kv_secrets_engines
      client = secrets_manager_client
      client.each_secrets_engine do |path, info|
        next unless info["type"] == "kv"

        client.disable_secrets_engine(path)
      end
    end

    def clean_all_pipeline_jwt_engines
      client = secrets_manager_client
      client.each_auth_engine do |path, info|
        next unless info["type"] == "jwt"
        next unless path.include? "pipeline_jwt"

        client.disable_auth_engine(path)
      end
    end

    def clean_all_policies
      client = secrets_manager_client
      client.each_acl_policy do |name|
        next unless name.start_with? "project_"

        client.delete_policy(name)
      end
    end

    def provision_project_secrets_manager(secrets_manager, user)
      ProjectSecretsManagers::ProvisionService.new(secrets_manager, user).execute
    end

    def expect_kv_secret_engine_to_be_mounted(path)
      expect { secrets_manager_client.read_secrets_engine_configuration(path) }.not_to raise_error
    end

    def expect_kv_secret_engine_not_to_be_mounted(path)
      expect { secrets_manager_client.read_secrets_engine_configuration(path) }
        .to raise_error(SecretsManagerClient::ApiError)
    end

    def expect_kv_secret_to_have_value(mount_path, path, value)
      stored_data = secrets_manager_client.read_kv_secret_value(mount_path, path)
      expect(stored_data).to eq(value)
    end

    def expect_kv_secret_to_have_custom_metadata(mount_path, path, metadata)
      stored_data = secrets_manager_client.read_secret_metadata(mount_path, path)
      expect(stored_data["custom_metadata"]).to include(metadata)
    end

    def expect_project_secret_not_to_exist(project, name, user = nil)
      user ||= create(:user)
      result = ProjectSecrets::ReadService.new(project, user).execute(name)
      expect(result).to be_error
      expect(result.message).to eq('Project secret does not exist.')
    end

    def expect_kv_secret_not_to_exist(mount_path, path)
      expect(secrets_manager_client.read_secret_metadata(mount_path, path)).to be_nil
      expect(secrets_manager_client.read_kv_secret_value(mount_path, path)).to be_nil
    end

    def expect_jwt_auth_engine_to_be_mounted(path)
      expect { secrets_manager_client.read_auth_engine_configuration(path) }.not_to raise_error
    end

    def expect_jwt_auth_engine_not_to_be_mounted(path)
      expect { secrets_manager_client.read_auth_engine_configuration(path) }
        .to raise_error(SecretsManagement::SecretsManagerClient::ApiError)
    end

    def expect_policy_not_to_exist(path)
      expect(secrets_manager_client.get_raw_policy(path)).to be_nil
    end

    def secrets_manager_client
      jwt = TestJwt.new.encoded

      TestClient.new(jwt: jwt)
    end

    def create_project_secret(user:, project:, name:, branch:, environment:, value:, description: nil)
      result = ProjectSecrets::CreateService.new(project, user).execute(
        name: name,
        value: value,
        description: description,
        branch: branch,
        environment: environment
      )

      project_secret = result.payload[:project_secret]

      if project_secret.errors.any?
        raise "project secret creation failed with errors: #{project_secret.errors.full_messages.to_sentence}"
      end

      project_secret
    end

    def update_secret_permission(user:, project:, principal:, permissions:, expired_at: nil)
      result = SecretsManagement::Permissions::UpdateService.new(project, user).execute(
        principal_id: principal[:id],
        principal_type: principal[:type],
        permissions: permissions,
        expired_at: expired_at
      )

      secret_permission = result.payload[:secret_permission]

      if secret_permission.errors.any?
        raise "secret permission creation failed with errors: #{secret_permission.errors.full_messages.to_sentence}"
      end

      secret_permission
    end
  end
end
