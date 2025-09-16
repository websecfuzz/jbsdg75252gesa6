# frozen_string_literal: true

module EE
  module ResourceAccessTokens
    module CreateService
      extend ::Gitlab::Utils::Override

      def execute
        super.tap do |response|
          audit_event_service(response.payload[:access_token], response)
        end
      end

      private

      override :reached_access_token_limit?
      def reached_access_token_limit?
        resource.is_a?(Project) && resource.namespace.reached_project_access_token_limit?
      end

      def success_message(token)
        if resource_type.in?(%w[project group])
          "Created #{resource_type} access token with token_id: #{token.id} with scopes: #{token.scopes} and #{resource.member(token.user).human_access} access level."
        else
          "Created #{resource_type} token with token_id: #{token.id} with scopes: #{token.scopes}."
        end
      end

      def audit_event_service(token, response)
        message = if response.success?
                    success_message(token)
                  else
                    "Attempted to create #{resource_type} access token but failed with message: #{response.message}"
                  end

        audit_context = {
          name: event_type(response),
          author: current_user,
          scope: resource,
          target: token || ::Gitlab::Audit::NullTarget.new,
          message: message,
          target_details: token&.user&.name,
          additional_details: { action: :custom }
        }

        ::Gitlab::Audit::Auditor.audit(audit_context)
      end

      def event_type(response)
        if response.success?
          "#{resource.class.name.downcase}_access_token_created"
        else
          "#{resource.class.name.downcase}_access_token_creation_failed"
        end
      end
    end
  end
end
