# frozen_string_literal: true

module Mutations
  # rubocop:disable Gitlab/BoundedContexts -- the MemberRole module already exists and holds the other mutations as well
  module MemberRoles
    module Admin
      class Delete < ::Mutations::BaseMutation
        graphql_name 'MemberRoleAdminDelete'

        authorize :delete_admin_role

        argument :id, ::Types::GlobalIDType[::MemberRole],
          required: true,
          description: 'ID of the admin member role to delete.'

        field :member_role, ::Types::MemberRoles::MemberRoleType, description: 'Deleted admin member role.'

        def resolve(**args)
          member_role = authorized_find!(id: args.delete(:id))

          unless Feature.enabled?(:custom_admin_roles, :instance)
            raise_resource_not_available_error! '`custom_admin_roles` feature flag is disabled.'
          end

          unless member_role.admin_related_role?
            raise Gitlab::Graphql::Errors::ArgumentError, 'This mutation is restricted to deleting admin roles only'
          end

          response = ::MemberRoles::DeleteService.new(current_user).execute(member_role)

          {
            member_role: response.payload,
            errors: response.errors
          }
        end
      end
    end
  end
  # rubocop:enable Gitlab/BoundedContexts
end
