# frozen_string_literal: true

module Gitlab
  module Llm
    module QAi
      class Client
        include ::Gitlab::Llm::Concerns::Logger
        include Gitlab::Utils::StrongMemoize

        def initialize(user)
          @user = user
        end

        def perform_create_auth_application(oauth_app, secret, role_arn)
          payload = {
            client_id: oauth_app.uid.to_s,
            client_secret: secret,
            redirect_url: oauth_app.redirect_uri,
            instance_url: Gitlab.config.gitlab.url,
            role_arn: role_arn
          }

          with_response_logger do
            Gitlab::HTTP.post(
              url(path: "/v1/amazon_q/oauth/application"),
              body: payload.to_json,
              headers: request_headers
            )
          end
        end

        def perform_delete_auth_application(role_arn)
          payload = {
            role_arn: role_arn
          }

          with_response_logger do
            Gitlab::HTTP.post(
              url(path: "/v1/amazon_q/oauth/application/delete"),
              body: payload.to_json,
              headers: request_headers
            )
          end
        end

        def create_event(payload:, role_arn:, event_id:)
          with_response_logger do
            Gitlab::HTTP.post(
              url(path: "/v1/amazon_q/events"),
              body: {
                payload: payload,
                code: create_auth_grant_new,
                role_arn: role_arn,
                event_id: event_id
              }.to_json,
              headers: request_headers
            )
          end
        end

        # This method tests the connection to the Amazon Q service by sending a POST request
        # to the /v1/amazon_q/oauth/application/verify endpoint.
        #
        # The response can either:
        # - Indicate an error with details, e.g., { "detail" => "error details" }
        # - Indicate a successful connection with statuses for GitLab reachability and credentials,
        # { 'GITLAB_INSTANCE_REACHABILITY': {'status': 'PASSED'}, 'GITLAB_CREDENTIAL_VALIDITY': {'status': 'PASSED'} }
        def test_connection(role_arn: ::Ai::Setting.instance.amazon_q_role_arn)
          with_response_logger do
            Gitlab::HTTP.post(
              url(path: "/v1/amazon_q/oauth/application/verify"),
              body: {
                role_arn: role_arn,
                code: create_auth_grant_new
              }.to_json,
              headers: request_headers
            )
          end
        end

        private

        attr_reader :user

        def create_auth_grant_new
          dynamic_user_scope = ["user:#{user.id}"]

          OauthAccessGrant.create!(
            resource_owner_id: ai_settings.amazon_q_service_account_user_id,
            application_id: ai_settings.amazon_q_oauth_application_id,
            redirect_uri: Gitlab::Routing.url_helpers.root_url,
            expires_in: 1.hour,
            scopes: Gitlab::Auth::Q_SCOPES + dynamic_user_scope,
            organization: Gitlab::Current::Organization.new(user: user).organization
          ).plaintext_token
        end

        def url(path:)
          # use append_path to handle potential trailing slash in AI Gateway URL
          Gitlab::Utils.append_path(Gitlab::AiGateway.url, path)
        end

        def service_name
          :amazon_q_integration
        end

        def service
          ::CloudConnector::AvailableServices.find_by_name(service_name)
        end

        def request_headers
          {
            "Accept" => "application/json",
            # Note: In this case, the service is the same as the unit primitive name
            'X-Gitlab-Unit-Primitive' => service_name.to_s
          }.merge(Gitlab::AiGateway.headers(user: user, service: service))
        end

        def with_response_logger
          yield.tap do |response|
            log_server_response(response)
          end
        end

        def log_server_response(response)
          if response.success?
            log_server_success(response)
          else
            log_server_error(response)
          end
        end

        def log_server_error(response)
          body = response.parsed_response['detail'] if response.parsed_response.is_a?(Hash)

          log_error(message: 'Error response from AI Gateway',
            event_name: 'error_response_received',
            ai_component: 'abstraction_layer',
            status: response.code,
            body: body)
        end

        def log_server_success(response)
          log_conditional_info(user,
            message: 'Received successful response from AI Gateway',
            ai_component: 'abstraction_layer',
            status: response.code,
            event_name: 'response_received')
        end

        def ai_settings
          ::Ai::Setting.instance
        end
        strong_memoize_attr :ai_settings
      end
    end
  end
end
