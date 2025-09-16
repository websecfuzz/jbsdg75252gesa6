# frozen_string_literal: true

module EE
  module PersonalAccessTokens
    module RevokeService
      include ::Gitlab::Allowable
      extend ::Gitlab::Utils::Override

      def execute
        super.tap do |response|
          send_audit_event(token, response)
        end
      end

      private

      override :revocation_permitted?

      def revocation_permitted?
        super || managed_user_revocation_allowed? || managed_service_account_revocation_allowed?
      end

      def managed_user_revocation_allowed?
        return unless token.present?

        token.user&.group_managed_account? &&
          token.user&.managing_group == group &&
          can?(current_user, :admin_group_credentials_inventory, group)
      end

      def managed_service_account_revocation_allowed?
        return false unless token.present?

        token.user.service_account? &&
          token.user.provisioned_by_group == group &&
          current_user.can?(:admin_service_accounts, token.user.provisioned_by_group)
      end

      def send_audit_event(token, response)
        return unless token

        message = if response.success?
                    "Revoked personal access token with id #{token.id}"
                  else
                    "Attempted to revoke personal access token with id #{token.id} but failed with message: #{response.message}"
                  end

        audit_context = {
          name: 'personal_access_token_revoked',
          author: current_user,
          scope: current_user,
          target: token&.user,
          message: message,
          additional_details: {
            revocation_source: source
          }
        }

        ::Gitlab::Audit::Auditor.audit(audit_context)
      end
    end
  end
end
