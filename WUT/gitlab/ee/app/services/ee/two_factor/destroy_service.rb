# frozen_string_literal: true

module EE
  module TwoFactor
    module DestroyService
      extend ::Gitlab::Utils::Override

      private

      override :authorized?
      def authorized?
        return super unless group

        user&.managed_by_user?(current_user, group: group)
      end

      override :notify_on_success
      def notify_on_success(user)
        audit_context = {
          name: 'user_disable_two_factor',
          author: current_user,
          scope: group || user,
          target: user,
          message: 'Disabled two-factor authentication',
          created_at: DateTime.current
        }

        ::Gitlab::Audit::Auditor.audit(audit_context)

        super
      end
    end
  end
end
