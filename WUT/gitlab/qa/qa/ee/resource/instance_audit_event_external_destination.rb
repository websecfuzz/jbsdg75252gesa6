# frozen_string_literal: true

module QA
  module EE
    module Resource
      # GraphQL mutations implemented as part of https://gitlab.com/gitlab-org/gitlab/-/issues/335175
      class InstanceAuditEventExternalDestination < QA::Resource::Base
        uses_admin_api_client

        attributes :id,
          :destination_url,
          :verification_token

        MAX_RETRY_ATTEMPTS = 6
        RETRY_SLEEP_DURATION = 10

        def initialize
          @mutation_retry_attempts = 0
        end

        def fabricate_via_api!
          super
        rescue ResourceFabricationFailedError => e
          # Until the feature flag is removed (see https://gitlab.com/gitlab-org/gitlab/-/issues/393772), toggling the
          # flag could lead to flakiness if the flag state is cached. So we retry the creation and fail if we don't
          # succeed after a minute
          raise unless e.message.include?('You do not have access to this mutation') ||
            e.message.include?('Requests to localhost are not allowed')

          raise if @mutation_retry_attempts >= MAX_RETRY_ATTEMPTS

          @mutation_retry_attempts += 1
          sleep RETRY_SLEEP_DURATION
          retry
        end

        def resource_web_url(resource)
          super
        rescue ResourceURLMissingError
          # this particular resource does not expose a web_url property
        end

        def gid
          "gid://gitlab/AuditEvents::InstanceExternalAuditEventDestination/#{id}"
        end

        # The path to get an instance audit event destination via the GraphQL API
        #
        # @return [String]
        def api_get_path
          "/graphql"
        end

        # The path to create an instance audit event destination via the GraphQL API (same as the GET path)
        #
        # @return [String]
        def api_post_path
          api_get_path
        end

        # Graphql mutation to create an instance audit event destination
        #
        # @return [String]
        def api_post_body
          <<~GQL
            mutation {
              instanceExternalAuditEventDestinationCreate(input: { #{mutation_params} }) {
                errors
                instanceExternalAuditEventDestination {
                  id
                  destinationUrl
                  verificationToken
                }
              }
            }
          GQL
        end

        # The path to delete an instance audit event destination via the GraphQL API (same as the GET path)
        #
        # @return [String]
        def api_delete_path
          api_get_path
        end

        # Graphql mutation to delete an instance audit event destination
        #
        # @return [String]
        def api_delete_body
          <<~GQL
            mutation {
              instanceExternalAuditEventDestinationDestroy(input: { id: "#{gid}" }) {
                errors
              }
            }
          GQL
        end

        # Graphql mutation to add event type filters
        #
        # @return [Hash]
        def add_filters(filters)
          mutation = <<~GQL
            mutation {
              auditEventsStreamingDestinationInstanceEventsAdd(input: {
                destinationId: "#{gid}",
                eventTypeFilters: ["#{filters.join('","')}"]
              }) {
                errors
                eventTypeFilters
              }
            }
          GQL
          api_post_to(api_get_path, mutation)
        end

        # Graphql mutation to add custom headers to the streamed events
        #
        # @return [void]
        def add_headers(headers)
          headers.each do |k, v|
            mutation = <<~GQL
              mutation {
                auditEventsStreamingInstanceHeadersCreate(input: {
                  destinationId: "#{gid}", key: "#{k}", value: "#{v}"
                }) {
                  errors
                }
              }
            GQL
            api_post_to(api_get_path, mutation)
          end
        end

        def process_api_response(parsed_response)
          event_response = extract_graphql_resource(parsed_response, 'instance_external_audit_event_destination')

          super(event_response)
        end

        protected

        # Return fields for comparing issues
        #
        # @return [Hash]
        def comparable
          reload! if api_response.nil?

          api_resource
        end

        private

        # Return available parameters formatted to be used in a GraphQL query
        #
        # @return [String]
        def mutation_params
          params = %(destinationUrl: "#{destination_url}")

          if defined?(@verification_token) && @verification_token.present?
            params += %(, verificationToken: "#{@verification_token}")
          end

          params
        end
      end
    end
  end
end
