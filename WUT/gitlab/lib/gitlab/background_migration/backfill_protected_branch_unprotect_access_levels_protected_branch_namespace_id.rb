# frozen_string_literal: true

module Gitlab
  module BackgroundMigration
    class BackfillProtectedBranchUnprotectAccessLevelsProtectedBranchNamespaceId < BackfillDesiredShardingKeyJob
      operation_name :backfill_protected_branch_unprotect_access_levels_protected_branch_namespace_id
      feature_category :source_code_management
    end
  end
end
