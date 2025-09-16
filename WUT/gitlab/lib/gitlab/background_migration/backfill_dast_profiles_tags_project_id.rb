# frozen_string_literal: true

module Gitlab
  module BackgroundMigration
    class BackfillDastProfilesTagsProjectId < BackfillDesiredShardingKeyJob
      operation_name :backfill_dast_profiles_tags_project_id
      feature_category :dynamic_application_security_testing
    end
  end
end
