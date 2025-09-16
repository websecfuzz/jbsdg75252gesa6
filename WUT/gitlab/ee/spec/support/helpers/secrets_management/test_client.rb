# frozen_string_literal: true

module SecretsManagement
  class TestClient < SecretsManagerClient
    def read_secrets_engine_configuration(mount_path)
      make_request(:get, "sys/mounts/#{mount_path}")
    end

    def read_auth_engine_configuration(mount_path)
      make_request(:get, "sys/auth/#{mount_path}")
    end

    def each_secrets_engine
      body = make_request(:get, "sys/mounts", {}, optional: true)
      return unless body

      body["data"].each do |path, info|
        yield(path, info)
      end
    end

    def each_auth_engine
      body = make_request(:get, "sys/auth", {}, optional: true)
      return unless body

      body["data"].each do |path, info|
        yield(path, info)
      end
    end

    def each_acl_policy
      body = make_request(:list, "sys/policies/acl", {}, optional: true)
      return unless body

      body["data"]["keys"].each do |policy|
        yield(policy)
      end
    end

    def read_kv_secret_value(mount_path, secret_path, version: nil)
      body = make_request(
        :get,
        "#{mount_path}/data/#{secret_path}",
        {
          version: version
        },
        optional: true
      )

      return unless body

      body.dig("data", "data", KV_VALUE_FIELD)
    end

    def configuration
      SecretsManagerClient.configuration
    end

    def get_raw_policy(name)
      read_raw_policy(name)
    end
  end
end
