# frozen_string_literal: true
module EE
  module Types
    module Repository
      module BlobType
        extend ActiveSupport::Concern
        include GrapePathHelpers::NamedRouteMatcher
        include ::EE::BlobHelper # rubocop: disable Cop/InjectEnterpriseEditionModule -- Using direct include for BlobHelper to access instance methods

        prepended do
          field :code_owners, [::Types::UserType],
            null: true,
            description: 'List of code owners for the blob.',
            calls_gitaly: true

          field :show_duo_workflow_action, GraphQL::Types::Boolean, null: true,
            description: 'Indicator to show Duo Agent Platform action.'

          field :duo_workflow_invoke_path, GraphQL::Types::String, null: true,
            description: 'Path to invoke Duo Agent Platform.'
        end

        def show_duo_workflow_action
          show_duo_workflow_action?(object)
        end

        def duo_workflow_invoke_path
          api_v4_ai_duo_workflows_workflows_path
        end
      end
    end
  end
end
