# frozen_string_literal: true

module MemberRoles
  class DeleteService < ::Authz::CustomRoles::BaseService
    def execute(role)
      @role = role

      return authorized_error unless allowed?

      return error(message: 'Custom role linked with a security policy.') if role.dependent_security_policies.exists?

      if role.destroy
        log_audit_event(action: :deleted)

        success
      else
        error
      end
    end

    def allowed?
      can?(current_user, :admin_member_role, role)
    end
  end
end
