# frozen_string_literal: true

module Authz
  module AdminRoles
    class CreateService < ::Authz::CustomRoles::BaseService
      def execute
        return authorized_error unless allowed?

        @role = build_role
        if role.save
          log_audit_event(action: :created)

          success
        else

          error
        end
      end

      private

      def build_role
        Authz::AdminRole.new(params)
      end

      def allowed?
        can?(current_user, :create_admin_role)
      end
    end
  end
end
