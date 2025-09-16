# frozen_string_literal: true

module Mutations
  module SecretsManagement
    module ProjectSecrets
      class Create < BaseMutation
        graphql_name 'ProjectSecretCreate'

        include ResolvesProject
        include Gitlab::InternalEventsTracking

        authorize :create_project_secrets

        argument :project_path, GraphQL::Types::ID,
          required: true,
          description: 'Project of the secret.'

        argument :name, GraphQL::Types::String,
          required: true,
          description: 'Name of the project secret.'

        argument :description, GraphQL::Types::String,
          required: false,
          description: 'Description of the project secret.'

        argument :secret, GraphQL::Types::String,
          required: true,
          description: 'Value of the project secret.'

        argument :environment, GraphQL::Types::String,
          required: true,
          description: 'Environments that can access the secret.'

        argument :branch, GraphQL::Types::String,
          required: true,
          description: 'Branches that can access the secret.'

        field :project_secret,
          Types::SecretsManagement::ProjectSecretType,
          null: true,
          description: "Project secret."

        def resolve(project_path:, name:, secret:, environment:, branch:, description: nil)
          project = authorized_find!(project_path: project_path)

          result = ::SecretsManagement::ProjectSecrets::CreateService
            .new(project, current_user)
            .execute(name: name, description: description, value: secret, environment: environment, branch: branch)

          if result.success?
            track_secret_creation_event(project)
            {
              project_secret: result.payload[:project_secret],
              errors: []
            }
          else
            {
              project_secret: nil,
              errors: errors_on_object(result.payload[:project_secret])
            }
          end
        end

        private

        def find_object(project_path:)
          resolve_project(full_path: project_path)
        end

        def track_secret_creation_event(project)
          track_internal_event(
            'create_ci_secret',
            user: current_user,
            namespace: project.namespace,
            project: project,
            additional_properties: {
              label: 'graphql'
            }
          )
        end
      end
    end
  end
end
