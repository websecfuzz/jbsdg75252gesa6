# frozen_string_literal: true

module EE
  module Branches
    module DeleteService
      extend ::Gitlab::Utils::Override

      override :execute
      def execute(branch_name)
        if protect_branch_modification_is_blocked_by_security_policy?(project, branch_name)
          return ServiceResponse.error(
            message: _('Deleting protected branches is blocked by security policies'),
            reason: :forbidden)
        end

        super
      end

      private

      def protect_branch_modification_is_blocked_by_security_policy?(project, branch_name)
        protected_branch = project.protected_branches.find_by_name(branch_name)

        return false unless protected_branch

        return false unless project.licensed_feature_available?(:security_orchestration_policies)

        service = ::Security::SecurityOrchestrationPolicies::ProtectedBranchesDeletionCheckService.new(project: project)
        protected_from_deletion = service.execute([protected_branch])

        protected_branch.in?(protected_from_deletion)
      end
    end
  end
end
