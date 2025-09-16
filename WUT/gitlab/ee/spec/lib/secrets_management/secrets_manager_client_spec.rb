# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::SecretsManagerClient, :gitlab_secrets_manager, feature_category: :secrets_management do
  let(:jwt) { SecretsManagement::TestJwt.new.encoded }
  let(:role) { described_class::DEFAULT_JWT_ROLE }
  let(:client) { described_class.new(jwt: jwt, role: role) }

  shared_examples_for 'making an invalid API request' do
    it 'raises an error' do
      expect { subject }.to raise_error(SecretsManagement::SecretsManagerClient::ApiError)
    end
  end

  describe '.configure' do
    # Store original configuration before tests
    let!(:original_host) { described_class.configuration.host }
    let!(:original_base_path) { described_class.configuration.base_path }

    after do
      # Reset the configuration to original settings
      described_class.configure do |config|
        config.host = original_host
        config.base_path = original_base_path
      end
    end

    it 'sets the configuration values' do
      described_class.configure do |config|
        config.host = 'http://test-host:8200'
        config.base_path = '/test-path/'
      end

      expect(described_class.configuration.host).to eq('http://test-host:8200')
      expect(described_class.configuration.base_path).to eq('/test-path/')
    end
  end

  describe '.expected_server_version' do
    it 'returns the content of GITLAB_OPENBAO_VERSION file' do
      path = Rails.root.join(described_class::SERVER_VERSION_FILE)
      version = path.read.chomp

      expect(described_class.expected_server_version).to eq(version)
    end
  end

  describe 'handling connection and authentication errors' do
    context 'when connection error occurs during API calls' do
      before do
        webmock_enable!(allow_localhost: false)

        # Then make the secrets engine request fail with connection error
        stub_request(:post, %r{#{described_class.configuration.host}/v1/sys/mounts})
          .to_raise(Errno::ECONNREFUSED)
      end

      after do
        # Reset WebMock to its previous state
        webmock_enable!(allow_localhost: true)
        WebMock.reset!
      end

      it 'raises ConnectionError for operations after authentication' do
        client = described_class.new(jwt: jwt, role: role)
        expect { client.enable_secrets_engine('test', 'kv-v2') }
          .to raise_error(described_class::ConnectionError)
      end
    end

    context 'when authentication error happens during API calls' do
      it 'raises AuthenticationError wrapping the connection error' do
        client = described_class.new(jwt: jwt, role: role, auth_mount: 'something_else')
        expect { client.enable_secrets_engine('test', 'kv-v2') }
          .to raise_error(described_class::AuthenticationError, /Failed to authenticate with OpenBao/)
      end
    end
  end

  describe '#enable_secrets_engine' do
    let(:mount_path) { 'some/test/path' }
    let(:engine) { 'kv-v2' }

    it 'enables the secrets engine' do
      client.enable_secrets_engine(mount_path, engine)

      expect_kv_secret_engine_to_be_mounted(mount_path)
    end
  end

  describe '#enable_auth_engine' do
    let(:mount_path) { 'auth/testing/pipeline_jwt' }
    let(:engine) { 'jwt' }

    it 'enables the secrets engine' do
      client.enable_auth_engine(mount_path, engine)

      expect_jwt_auth_engine_to_be_mounted(mount_path)
    end

    context 'when the engine already exists' do
      before do
        client.enable_auth_engine(mount_path, engine)
      end

      it 'raises an error by default' do
        expect { client.enable_auth_engine(mount_path, engine) }
          .to raise_error(described_class::ApiError)
      end

      it 'returns true when allow_existing is true' do
        expect(client.enable_auth_engine(mount_path, engine, allow_existing: true)).to be true
      end
    end
  end

  describe '#disable_auth_engine' do
    let(:mount_path) { 'auth/testing/pipeline_jwt' }
    let(:engine) { 'jwt' }

    it 'disables the auth engine' do
      client.enable_auth_engine(mount_path, engine)
      expect_jwt_auth_engine_to_be_mounted(mount_path)

      client.disable_auth_engine(mount_path)
      expect_jwt_auth_engine_not_to_be_mounted(mount_path)
    end
  end

  describe '#disable_secrets_engine' do
    let(:mount_path) { 'some/test/path' }

    it 'disables the secrets engine' do
      client.enable_secrets_engine(mount_path, 'kv-v2')

      expect_kv_secret_engine_to_be_mounted(mount_path)

      client.disable_secrets_engine(mount_path)

      expect_kv_secret_engine_not_to_be_mounted(mount_path)
    end
  end

  describe '#configure_jwt' do
    let(:mount_path) { 'auth/testing/pipeline_jwt' }
    let(:server_url) { 'https://gitlab.example.com' }
    let(:jwk_signer) { Gitlab::CurrentSettings.ci_jwt_signing_key }

    before do
      client.enable_auth_engine(mount_path, 'jwt')
    end

    it 'configures the JWT auth method' do
      expect { client.configure_jwt(mount_path, server_url, jwk_signer) }.not_to raise_error

      # Verify we can create a role on the configured JWT backend
      expect do
        client.update_jwt_role(
          mount_path,
          'test-role',
          user_claim: 'project_id',
          role_type: 'jwt',
          bound_claims: { project_id: 123 },
          token_policies: ['test-policy']
        )
      end.not_to raise_error
    end
  end

  describe '#update_jwt_role and #read_jwt_role' do
    let(:mount_path) { 'auth/testing/pipeline_jwt' }
    let(:role_name) { 'test-role' }
    let(:server_url) { 'https://gitlab.example.com' }
    let(:jwk_signer) { Gitlab::CurrentSettings.ci_jwt_signing_key }

    let(:role_data) do
      {
        role_type: 'jwt',
        user_claim: 'project_id', # Required field
        bound_claims: { project_id: 123 },
        token_policies: ['test-policy']
      }
    end

    before do
      client.enable_auth_engine(mount_path, 'jwt')
      client.configure_jwt(mount_path, server_url, jwk_signer)
    end

    it 'creates and reads a JWT role' do
      # Create the role
      client.update_jwt_role(mount_path, role_name, **role_data)

      # Read the role back
      role = client.read_jwt_role(mount_path, role_name)

      # Verify the role data
      expect(role).to be_present
      expect(role['token_ttl']).to eq(900)
      expect(role['token_max_ttl']).to eq(900)
      expect(role['bound_claims']['project_id']).to eq(123)
      expect(role['token_policies']).to include('test-policy')
      expect(role['user_claim']).to eq('project_id')
    end

    it 'raises an error when reading a non-existent role' do
      expect { client.read_jwt_role(mount_path, 'non-existent-role') }
        .to raise_error(SecretsManagement::SecretsManagerClient::ApiError)
    end
  end

  describe '#list_secrets' do
    let(:mount_path) { 'some/mount/path' }
    let(:other_mount_path) { 'other/mount/path' }
    let(:secrets_path) { 'secrets' }
    let(:target_mount_path) { mount_path }
    let(:target_secrets_path) { secrets_path }

    before do
      client.enable_secrets_engine(mount_path, 'kv-v2')
      client.enable_secrets_engine(other_mount_path, 'kv-v2')

      update_kv_secret_with_metadata(
        mount_path,
        "#{secrets_path}/DBPASS",
        'somevalue',
        environment: 'staging'
      )

      update_kv_secret_with_metadata(
        mount_path,
        "other_secrets/APIKEY",
        'somevalue',
        environment: 'staging'
      )

      update_kv_secret_with_metadata(
        other_mount_path,
        "#{secrets_path}/DEPLOYKEY",
        'somevalue',
        environment: 'staging'
      )
    end

    subject(:result) { client.list_secrets(target_mount_path, target_secrets_path) }

    it 'returns all matching secrets' do
      expect(result).to contain_exactly(
        a_hash_including(
          "key" => "DBPASS",
          "metadata" => a_hash_including(
            "current_version" => 1,
            "custom_metadata" => a_hash_including(
              "environment" => "staging"
            )
          )
        )
      )
    end

    context 'when mount path does not exist' do
      let(:target_mount_path) { 'something/else' }

      it_behaves_like 'making an invalid API request'
    end

    context 'when secrets path does not exist' do
      let(:target_secrets_path) { 'something/else' }

      it { is_expected.to eq([]) }
    end

    context 'when block is given' do
      it 'yields each entry and returns in the list the returned value of each block' do
        result = client.list_secrets(mount_path, secrets_path) do |data|
          { new_data: data["key"] }
        end

        expect(result).to contain_exactly(new_data: "DBPASS")
      end
    end
  end

  describe '#read_secret_metadata' do
    let(:existing_mount_path) { 'secrets' }
    let(:existing_secret_path) { 'DBPASS' }
    let(:mount_path) { existing_mount_path }
    let(:secret_path) { existing_secret_path }

    before do
      client.enable_secrets_engine(existing_mount_path, 'kv-v2')

      update_kv_secret_with_metadata(
        existing_mount_path,
        existing_secret_path,
        'somevalue',
        environment: 'staging'
      )
    end

    subject(:result) { client.read_secret_metadata(mount_path, secret_path) }

    context 'when the secret exists' do
      it 'returns the metadata' do
        expect(result).to match(
          a_hash_including(
            "custom_metadata" => a_hash_including(
              "environment" => "staging"
            )
          )
        )
      end
    end

    context 'when the mount path does not exist' do
      let(:mount_path) { 'something/else' }

      it_behaves_like 'making an invalid API request'
    end

    context 'when the secret does not exist' do
      let(:secret_path) { 'something/else' }

      it { is_expected.to be_nil }
    end
  end

  describe '#update_kv_secret' do
    let(:existing_mount_path) { 'some/test/path' }
    let(:mount_path) { existing_mount_path }
    let(:secret_path) { 'DBPASS' }
    let(:value) { 'somevalue' }
    let(:cas) { 0 }

    before do
      client.enable_secrets_engine(existing_mount_path, 'kv-v2')
    end

    subject(:call_api) { client.update_kv_secret(mount_path, secret_path, value, cas: cas) }

    context 'when the mount path exists' do
      context 'when the given secret path does not exist' do
        it 'creates the secret and the custom metadata' do
          call_api

          expect_kv_secret_to_have_value(mount_path, secret_path, value)
        end

        it 'returns the response of the API call' do
          expect(call_api["data"]).to match(a_hash_including("version" => 1))
        end
      end

      context 'when the given secret path exists' do
        before do
          client.update_kv_secret(mount_path, secret_path, 'someexistingvalue')
        end

        context 'and given cas is 0' do
          it_behaves_like 'making an invalid API request'
        end

        context 'and given cas is not equal to the current version of the secret' do
          let(:cas) { 3 }

          it_behaves_like 'making an invalid API request'
        end

        shared_examples_for 'successful update' do
          it 'updates the secret value' do
            call_api

            expect_kv_secret_to_have_value(mount_path, secret_path, value)
          end
        end

        context 'and given cas is equal to the current version of the secret' do
          let(:cas) { 1 }

          it_behaves_like 'successful update'
        end

        context 'and cas is not given' do
          let(:cas) { nil }

          it_behaves_like 'successful update'
        end
      end
    end

    context 'when the mount path does not exist' do
      let(:mount_path) { 'something/else' }

      it_behaves_like 'making an invalid API request'
    end
  end

  describe '#update_kv_secret_metadata' do
    let(:existing_mount_path) { 'some/test/path' }
    let(:mount_path) { existing_mount_path }
    let(:secret_path) { 'DBPASS' }
    let(:cas) { 0 }

    let(:custom_metadata) do
      {
        environment: 'staging'
      }
    end

    before do
      client.enable_secrets_engine(existing_mount_path, 'kv-v2')
    end

    subject(:call_api) { client.update_kv_secret_metadata(mount_path, secret_path, custom_metadata, metadata_cas: cas) }

    context 'when the mount path exists' do
      context 'when the given secret path does not exist' do
        it 'creates the secret and the custom metadata' do
          call_api

          expect_kv_secret_to_have_custom_metadata(mount_path, secret_path, custom_metadata.stringify_keys)
        end
      end

      context 'when the given secret path exists' do
        before do
          client.update_kv_secret_metadata(mount_path, secret_path, { environment: 'prod' })
        end

        shared_examples_for 'updating custom metadata' do
          it 'updates the custom metadata' do
            call_api

            expect_kv_secret_to_have_custom_metadata(mount_path, secret_path, custom_metadata.stringify_keys)
          end
        end

        context 'and the given metadata_cas matches the current version' do
          let(:cas) { 1 }

          it_behaves_like 'updating custom metadata'
        end

        context 'and no metadata_cas is given' do
          let(:cas) { nil }

          it_behaves_like 'updating custom metadata'
        end

        context 'and the given metadata_version does not match the current version' do
          it_behaves_like 'making an invalid API request'
        end
      end
    end

    context 'when the mount path does not exist' do
      let(:mount_path) { 'something/else' }

      it_behaves_like 'making an invalid API request'
    end
  end

  shared_context 'with policy management' do
    let(:name) { 'project_test' }

    let(:acl_policy) do
      SecretsManagement::AclPolicy.build_from_hash(
        name,
        {
          "path" => {
            "test/secrets/*" => {
              "capabilities" => ["create"],
              "required_parameters" => ["something_required"],
              "allowed_parameters" => {
                "something_allowed" => ["allowed_value"]
              },
              "denied_parameters" => {
                "something_denied" => ["denied_value"]
              }
            }
          }
        }
      )
    end
  end

  describe '#set_policy' do
    include_context 'with policy management'

    subject(:call_api) { client.set_policy(acl_policy) }

    it 'creates the policy' do
      call_api

      policy = client.get_policy(name)
      expect(policy.to_openbao_attributes).to match(
        acl_policy.to_openbao_attributes
      )
    end
  end

  describe '#list_project_policies' do
    let(:project_id) { 123 }

    context 'when no policies exist' do
      it 'returns an empty array' do
        result = client.list_project_policies(project_id: project_id)

        expect(result).to eq([])
      end
    end

    context 'when policies exist' do
      before do
        client.set_policy(SecretsManagement::AclPolicy.new("project_123/users/direct/user_123"))
        client.set_policy(SecretsManagement::AclPolicy.new("project_123/users/direct/user_124"))
      end

      it 'returns an array of policy data' do
        result = client.list_project_policies(project_id: project_id)

        expect(result).to be_an(Array)
        expect(result.size).to eq(2)
        expect(result[0]['key']).to eq('project_123/users/direct/user_123')
        expect(result[1]['key']).to eq('project_123/users/direct/user_124')
      end
    end
  end

  describe '#get_policy' do
    include_context 'with policy management'

    subject(:result) { client.get_policy(name) }

    context 'when the policy exists' do
      before do
        client.set_policy(acl_policy)
      end

      it 'fetches the policy' do
        expect(result.to_openbao_attributes).to match(
          acl_policy.to_openbao_attributes
        )
      end
    end

    context 'when the policy does not exist' do
      it 'returns an empty policy object' do
        expect(result.to_openbao_attributes).to match(path: {})
      end
    end
  end

  describe '#delete_policy' do
    include_context 'with policy management'

    subject(:call_api) { client.delete_policy(name) }

    context 'when the policy exists' do
      before do
        client.set_policy(acl_policy)
      end

      it 'deletes the policy' do
        expect { call_api }.not_to raise_error

        policy = client.get_policy(name)
        expect(policy.to_openbao_attributes).to match(path: {})
      end
    end

    context 'when the policy does not exist' do
      it 'deletes nothing and fails silently' do
        expect { call_api }.not_to raise_error
      end
    end
  end

  describe '#delete_kv_secret' do
    let(:existing_mount_path) { 'secrets' }
    let(:existing_secret_path) { 'DBPASS' }
    let(:mount_path) { existing_mount_path }
    let(:secret_path) { existing_secret_path }

    subject(:call_api) { client.delete_kv_secret(mount_path, secret_path) }

    before do
      client.enable_secrets_engine(existing_mount_path, 'kv-v2')

      update_kv_secret_with_metadata(
        existing_mount_path,
        existing_secret_path,
        'somevalue',
        environment: 'staging'
      )
    end

    context 'when the mount path exists' do
      context 'when the given secret path exists' do
        it 'deletes the secret permanently' do
          call_api

          expect_kv_secret_not_to_exist(mount_path, secret_path)
        end
      end

      context 'when the given secret path does not exist' do
        let(:secret_path) { 'SOMETHING_ELSE' }

        it 'does not fail' do
          expect { call_api }.not_to raise_error
        end
      end
    end

    context 'when the mount path does not exist' do
      let(:mount_path) { 'something/else' }

      it_behaves_like 'making an invalid API request'
    end
  end

  def update_kv_secret_with_metadata(mount_path, secret_path, value, custom_metadata)
    client.update_kv_secret(
      mount_path,
      secret_path,
      value
    )

    client.update_kv_secret_metadata(
      mount_path,
      secret_path,
      custom_metadata
    )
  end
end
