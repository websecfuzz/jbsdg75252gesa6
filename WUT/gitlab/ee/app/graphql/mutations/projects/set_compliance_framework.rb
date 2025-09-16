# frozen_string_literal: true

module Mutations
  module Projects
    class SetComplianceFramework < BaseMutation
      graphql_name 'ProjectSetComplianceFramework'
      description 'Assign (or unset) a compliance framework to a project. ' \
        'This mutation raises an error if the project has more than ' \
        'one compliance framework associated with it.'

      authorize :admin_compliance_framework

      argument :project_id, Types::GlobalIDType[::Project],
        required: true,
        description: 'ID of the project to change the compliance framework of.'

      argument :compliance_framework_id, Types::GlobalIDType[::ComplianceManagement::Framework],
        required: false,
        description: 'ID of the compliance framework to assign to the project. Set to `null` to unset.'

      field :project,
        Types::ProjectType,
        null: true,
        description: "Project after mutation."

      def resolve(project_id:, compliance_framework_id:)
        project = GitlabSchema.find_by_gid(project_id).sync

        authorize!(project)

        service_response = ::ComplianceManagement::Frameworks::AssignProjectService
                     .new(project, current_user, framework: compliance_framework_id&.model_id)
                     .execute

        { project: project, errors: errors_on_object(project) + service_response.errors }
      end
    end
  end
end
