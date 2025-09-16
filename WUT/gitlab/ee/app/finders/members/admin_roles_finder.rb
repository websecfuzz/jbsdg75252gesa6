# frozen_string_literal: true

module Members
  class AdminRolesFinder < MemberRoles::RolesFinder
    private

    def member_roles
      can_return_admin_roles? ? MemberRole.admin : MemberRole.none
    end

    def validate_arguments!
      return if current_user.can?(:read_admin_role)

      super
    end
  end
end
