# frozen_string_literal: true

module Gitlab
  module BackgroundMigration
    class MigrateRemainingSoftwareLicenseWithoutSpdxIdentifierToCustomLicenses < BatchedMigrationJob
      feature_category :security_policy_management

      def perform; end
    end
  end
end

Gitlab::BackgroundMigration::MigrateRemainingSoftwareLicenseWithoutSpdxIdentifierToCustomLicenses.prepend_mod
