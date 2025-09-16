# frozen_string_literal: true

module EE
  module Projects
    module MarkForDeletionService
      extend ::Gitlab::Utils::Override
      include SecurityOrchestrationHelper

      override :execute
      def execute
        return success if project.marked_for_deletion_at?

        if reject_security_policy_project_deletion?
          return error(
            s_('SecurityOrchestration|Project cannot be deleted because it is linked as a security policy project')
          )
        end

        super
      end

      private

      override :log_event
      def log_event
        log_audit_event

        super
      end

      def log_audit_event
        audit_context = {
          name: 'project_deletion_marked',
          author: current_user,
          scope: project,
          target: project,
          message: 'Project marked for deletion',
          additional_details: {
            project_id: project.id,
            namespace_id: project.namespace_id,
            root_namespace_id: project.root_namespace.id
          }
        }

        ::Gitlab::Audit::Auditor.audit(audit_context)
      end

      def reject_security_policy_project_deletion?
        security_configurations_preventing_project_deletion(project).exists?
      end
    end
  end
end
