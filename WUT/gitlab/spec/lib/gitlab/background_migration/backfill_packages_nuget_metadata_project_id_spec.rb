# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::BackfillPackagesNugetMetadataProjectId,
  feature_category: :package_registry,
  schema: 20240930121132 do
  include_examples 'desired sharding key backfill job' do
    let(:batch_table) { :packages_nuget_metadata }
    let(:batch_column) { :package_id }
    let(:backfill_column) { :project_id }
    let(:backfill_via_table) { :packages_packages }
    let(:backfill_via_column) { :project_id }
    let(:backfill_via_foreign_key) { :package_id }
  end
end
