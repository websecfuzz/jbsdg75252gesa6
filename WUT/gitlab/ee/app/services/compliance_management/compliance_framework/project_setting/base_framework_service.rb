# frozen_string_literal: true

module ComplianceManagement
  module ComplianceFramework
    module ProjectSetting
      class BaseFrameworkService < BaseService
        def initialize(project_id:, current_user:, framework:)
          @project_id = project_id
          @current_user = current_user
          @framework = framework
        end

        def execute
          return ServiceResponse.error(message: 'Not permitted to create framework') unless permitted?

          @project = Project.find(@project_id)
          project_framework_mismatch_error unless project_framework_same_namespace?
        end

        private

        attr_reader :project, :current_user, :framework

        def permitted?
          can? current_user, :admin_compliance_framework, framework
        end

        def project_framework_same_namespace?
          project.root_ancestor&.id == framework.namespace_id
        end

        def publish_event(event_type)
          event = ::Projects::ComplianceFrameworkChangedEvent.new(data: {
            project_id: project.id,
            compliance_framework_id: framework.id,
            event_type: event_type
          })

          ::Gitlab::EventStore.publish(event)
        end

        def audit_event(event_type)
          audit_context = {
            name: "compliance_framework_#{event_type}",
            author: current_user,
            scope: project,
            target: framework,
            message: %(#{event_type.capitalize} 'framework label': "#{framework.name}"),
            additional_details: {
              framework: {
                id: framework.id,
                name: framework.name
              }
            }
          }

          ::Gitlab::Audit::Auditor.audit(audit_context)
        end

        def success
          ServiceResponse.success
        end

        def project_framework_mismatch_error
          ServiceResponse.error(
            message: format(_('Project %{project_name} and framework are not from same namespace.'),
              project_name: project.name
            )
          )
        end
      end
    end
  end
end
