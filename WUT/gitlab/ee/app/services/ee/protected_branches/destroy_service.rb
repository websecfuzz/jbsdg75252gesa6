# frozen_string_literal: true

module EE
  module ProtectedBranches
    module DestroyService
      extend ::Gitlab::Utils::Override
      include Loggable

      override :execute
      def execute(protected_branch)
        raise ::Gitlab::Access::AccessDeniedError if blocked_by_scan_result_policy?(protected_branch)

        super(protected_branch).tap do |protected_branch_service|
          # DestroyService returns the value of #.destroy instead of the
          # instance, in comparison with the other services
          # (CreateService and UpdateService) so if the destroy service
          # doesn't succeed the value will be false instead of an instance
          log_audit_event(protected_branch_service, :remove) if protected_branch_service
        end
      end

      private

      def blocked_by_scan_result_policy?(protected_branch)
        return blocked_on_project_level?(protected_branch) if protected_branch.project_level?

        blocked_on_group_level?(protected_branch)
      end

      def blocked_on_project_level?(protected_branch)
        project = protected_branch.project

        return false unless project&.licensed_feature_available?(:security_orchestration_policies)

        service = ::Security::SecurityOrchestrationPolicies::ProtectedBranchesDeletionCheckService.new(project: project)
        protected_from_deletion = service.execute([protected_branch])

        protected_branch.in?(protected_from_deletion)
      end

      def blocked_on_group_level?(protected_branch)
        ::Security::SecurityOrchestrationPolicies::GroupProtectedBranchesDeletionCheckService
          .new(group: protected_branch.group)
          .execute
      end
    end
  end
end
