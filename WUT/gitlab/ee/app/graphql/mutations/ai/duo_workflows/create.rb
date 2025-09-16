# frozen_string_literal: true

module Mutations
  module Ai
    module DuoWorkflows
      class Create < BaseMutation
        graphql_name 'AiDuoWorkflowCreate'

        # The actual auth check is performed by authorize_workflow based on the workflow definition
        authorize :developer_access

        def self.authorization_scopes
          super + [:ai_features]
        end

        argument :project_id, ::Types::GlobalIDType[::Project],
          required: false,
          description: "Global ID of the project the user is acting on."

        argument :goal, GraphQL::Types::String,
          required: false,
          description: 'Goal of the workflow.'

        argument :agent_privileges, [GraphQL::Types::Int],
          required: false,
          description: 'Actions the agent is allowed to perform.'

        argument :pre_approved_agent_privileges, [GraphQL::Types::Int],
          required: false,
          description: 'Actions the agent can perform without asking for approval.'

        argument :workflow_definition, GraphQL::Types::String,
          required: false,
          description: 'Workflow type based on its capability.'

        argument :allow_agent_to_request_user, GraphQL::Types::Boolean,
          required: false,
          description: 'When enabled, Duo Agent Platform may stop to ask the user questions before proceeding.'

        argument :environment, Types::Ai::DuoWorkflows::WorkflowEnvironmentEnum,
          required: false,
          description: 'Environment for the workflow.'

        field :workflow, Types::Ai::DuoWorkflows::WorkflowType,
          null: true,
          description: 'Created workflow.'

        field :errors, [GraphQL::Types::String],
          null: false,
          description: 'Errors encountered during the creation process.'

        def resolve(**args)
          project = authorized_find!(id: args[:project_id])

          authorize_workflow!(project, args[:workflow_definition])

          workflow_params = {
            project_id: project.id,
            goal: args[:goal],
            agent_privileges: args[:agent_privileges],
            pre_approved_agent_privileges: args[:pre_approved_agent_privileges],
            workflow_definition: args[:workflow_definition],
            allow_agent_to_request_user: args[:allow_agent_to_request_user],
            environment: args[:environment]
          }.compact

          service = ::Ai::DuoWorkflows::CreateWorkflowService.new(
            project: project,
            current_user: current_user,
            params: workflow_params
          )

          result = service.execute

          return { errors: [result[:message]], workflow: nil } if result[:status] == :error

          {
            workflow: result[:workflow],
            errors: errors_on_object(result[:workflow])
          }
        end

        private

        def authorize_workflow!(project, workflow_definition)
          if workflow_definition == 'chat'
            return if current_user.can?(:access_duo_agentic_chat, project)
          elsif current_user.can?(:duo_workflow, project)
            return
          end

          raise_resource_not_available_error!
        end
      end
    end
  end
end
