# frozen_string_literal: true

module Mutations
  module Ci
    module Pipeline
      class Create < BaseMutation
        graphql_name 'PipelineCreate'

        include FindsProject

        EXECUTE_OPTIONS = { ignore_skip_ci: true, save_on_errors: false }.freeze
        INTERNAL_CREATE_OPERATION_NAME = 'internalPipelineCreate'

        field :pipeline,
          Types::Ci::PipelineType,
          null: true,
          description: 'Pipeline created after mutation. Null if `async: true`.'

        field :request_id,
          GraphQL::Types::String,
          null: true,
          description: 'ID for checking the pipeline creation status. Null if `async: false`.',
          experiment: { milestone: '17.8' }

        argument :async, GraphQL::Types::Boolean,
          required: false,
          description: 'When `true`, the request does not wait for the pipeline to be created, ' \
            'and returns a unique identifier that can be used to check the creation status.',
          experiment: { milestone: '17.8' }

        argument :project_path, GraphQL::Types::ID,
          required: true,
          description: 'Full path of the project that is triggering the pipeline.'

        argument :ref, GraphQL::Types::String,
          required: true,
          description: 'Ref on which to run the pipeline.'

        argument :variables, [Types::Ci::VariableInputType],
          required: false,
          description: 'Variables for the pipeline.'

        argument :inputs, [Types::Ci::Inputs::InputType],
          required: false,
          description: 'Inputs for the pipeline.',
          experiment: { milestone: '17.10' }

        authorize :create_pipeline

        def resolve(project_path:, ref:, async: false, variables: {}, inputs: [])
          project = authorized_find!(project_path)
          creation_params = { ref: ref, variables_attributes: variables.map(&:to_h) }

          execute_options = EXECUTE_OPTIONS.merge(inputs: parse_inputs(inputs))

          service = ::Ci::CreatePipelineService.new(project, current_user, creation_params)
          response = execute_service(service, source, async, execute_options)

          if response.success?
            if async
              { request_id: response.payload, errors: [] }
            else
              { pipeline: response.payload, errors: [] }
            end
          else
            { pipeline: nil, errors: [response.message] }
          end
        end

        private

        def execute_service(service, source, async, options)
          if async
            service.execute_async(source, options)
          else
            service.execute(source, **options)
          end
        end

        def source
          return 'web' if context.query.operation_name == INTERNAL_CREATE_OPERATION_NAME

          'api'
        end

        def parse_inputs(inputs)
          inputs.to_h { |input| [input.name, input.value] }
        end
      end
    end
  end
end
