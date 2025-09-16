# frozen_string_literal: true

module SecretsManagement
  class OpenbaoTestSetup
    SERVER_ADDRESS = '127.0.0.1:9800'
    SERVER_URI_TO_PING = "http://#{SERVER_ADDRESS}/v1/sys/health".freeze

    class << self
      def install_dir
        File.join('tmp', 'tests', 'openbao')
      end

      def bin_path
        File.join(install_dir, 'bin', 'bao')
      end

      def build_openbao_binary
        if File.exist?(bin_path)
          # In CI, this should also be true if the cache has been warmed up
          puts 'OpenBao binary already built. Skip building...'
          true
        else
          puts 'OpenBao binary not yet built. Building...'
          system("make clean build > /dev/null", chdir: install_dir)
        end
      end

      def start_server
        return if server_running?

        puts "Starting up OpenBao server..."

        server_pid = Process.spawn(
          %(#{bin_path} server -dev -dev-root-token-id=root -dev-listen-address="#{SERVER_ADDRESS}"),
          [:out, :err] => "log/test-openbao-server.log"
        )

        at_exit do
          Process.kill("TERM", server_pid)
        end

        wait_for_ready
      end

      def configure_jwt_auth(jwt_public_key)
        opts = "-address=http://#{SERVER_ADDRESS}"
        policy_path = File.join(__dir__, 'test_jwt_policy.hcl')

        # Redirect both stdout and stderr to /dev/null for all commands
        # Try to enable JWT auth - fail silently if already enabled
        jwt_path = SecretsManagerClient::GITLAB_JWT_AUTH_PATH
        system(%(#{bin_path} auth enable #{opts} -path=#{jwt_path} jwt >/dev/null 2>&1))

        # Always update the JWT config with the new public key
        system(%(#{bin_path} write #{opts} auth/#{jwt_path}/config \
                 bound_issuer="#{Gitlab.config.gitlab.url}" \
                 jwt_validation_pubkeys="#{jwt_public_key}" >/dev/null 2>&1))

        # Update role configuration
        role = SecretsManagerClient::DEFAULT_JWT_ROLE
        system(%(#{bin_path} write #{opts} auth/#{jwt_path}/role/#{role} \
                 role_type=jwt \
                 bound_audiences=openbao \
                 user_claim=user_id \
                 token_policies=secrets_manager >/dev/null 2>&1))

        # Update policy configuration
        system(%(#{bin_path} policy write #{opts} secrets_manager #{policy_path} >/dev/null 2>&1))
      end

      def server_running?
        ping_success?(SERVER_URI_TO_PING)
      rescue Errno::ECONNREFUSED
        false
      end

      private

      def ping_success?(uri)
        uri = URI(uri)
        response = Net::HTTP.get_response(uri)
        response.code.to_i == 200
      end

      def wait_for_ready
        Timeout.timeout(15) do
          loop do
            begin
              break if ping_success?(SERVER_URI_TO_PING)

              raise "OpenBao server responded with #{response.code}."
            rescue Errno::ECONNREFUSED
              puts "Waiting for OpenBao server to start..."
            end
            sleep 2
          end
          puts "OpenBao server started..."
        end
      rescue Timeout::Error
        puts "Check log/test-openbao-server.log for more information."
        puts "You may need to setup the environment variable export BAO_ADDR='http://127.0.0.1:9800'"
        raise "Timed out waiting for OpenBao #{service} to start."
      end
    end
  end
end
