# frozen_string_literal: true

module Mutations
  module Security
    module CiConfiguration
      class SetContainerScanningForRegistry < BaseMutation
        graphql_name 'SetContainerScanningForRegistry'

        include FindsNamespace

        description <<~DESC
          Enable/disable Container Scanning on container registry for the given project.
        DESC

        argument :namespace_path, GraphQL::Types::ID,
          required: true,
          description: 'Full path of the namespace (project).'

        argument :enable, GraphQL::Types::Boolean,
          required: true,
          description: 'Desired status for Container Scanning on container registry feature.'

        field :container_scanning_for_registry_enabled, GraphQL::Types::Boolean,
          null: true,
          description: 'Whether the feature is enabled.'

        authorize :enable_container_scanning_for_registry

        def resolve(namespace_path:, enable:)
          namespace = find_namespace(namespace_path)

          response = ::Security::Configuration::SetContainerScanningForRegistryService
            .execute(namespace: namespace, enable: enable)

          { container_scanning_for_registry_enabled: response.payload[:enabled], errors: response.errors }
        end

        private

        def find_namespace(namespace_path)
          namespace = authorized_find!(namespace_path)
          # This will be removed following the completion of https://gitlab.com/gitlab-org/gitlab/-/issues/451430
          unless namespace.is_a? Project
            raise_resource_not_available_error! 'Setting only available for Project namespaces.'
          end

          namespace
        end
      end
    end
  end
end
