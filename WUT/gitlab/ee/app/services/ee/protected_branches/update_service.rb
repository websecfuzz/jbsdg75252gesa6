# frozen_string_literal: true

module EE
  module ProtectedBranches
    module UpdateService
      prepend ForcePushChangesBlockedByPolicy
      prepend RenamingBlockedByPolicy

      def after_execute(protected_branch:, old_merge_access_levels:, old_push_access_levels:)
        super

        ::Repositories::ProtectedBranchesChangesAuditor.new(current_user, protected_branch, old_merge_access_levels, old_push_access_levels).execute
      end
    end
  end
end
