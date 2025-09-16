# frozen_string_literal: true

module EE
  module Projects
    module RestoreService
      extend ::Gitlab::Utils::Override

      private

      override :log_event
      def log_event
        log_audit_event

        super
      end

      def log_audit_event
        audit_context = {
          name: 'project_restored',
          author: current_user,
          scope: project,
          target: project,
          message: 'Project restored'
        }

        ::Gitlab::Audit::Auditor.audit(audit_context)
      end
    end
  end
end
