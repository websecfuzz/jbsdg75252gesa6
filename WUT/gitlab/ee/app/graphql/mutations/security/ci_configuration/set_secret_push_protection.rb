# frozen_string_literal: true

module Mutations
  module Security
    module CiConfiguration
      class SetSecretPushProtection < BaseMutation
        graphql_name 'SetSecretPushProtection'

        include ResolvesProject

        description <<~DESC
          Enable/disable secret push protection for the given project.
        DESC

        argument :namespace_path, GraphQL::Types::ID,
          required: true,
          description: 'Full path of the namespace (project).'

        argument :enable, GraphQL::Types::Boolean,
          required: true,
          description: 'Desired status for secret push protection feature.'

        field :pre_receive_secret_detection_enabled, GraphQL::Types::Boolean,
          null: true,
          description: 'Whether the feature is enabled.'

        field :secret_push_protection_enabled, GraphQL::Types::Boolean,
          null: true,
          description: 'Whether the feature is enabled.'

        authorize :enable_secret_push_protection

        def resolve(namespace_path:, enable:)
          project = authorized_find!(project_path: namespace_path)

          response = ::Security::Configuration::SetSecretPushProtectionService
            .execute(current_user: current_user, project: project, enable: enable)

          { secret_push_protection_enabled: response.payload[:enabled], errors: response.errors }
        end

        private

        def find_object(project_path:)
          resolve_project(full_path: project_path)
        end
      end
    end
  end
end
