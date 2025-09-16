# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::BackfillStatusCheckResponsesProjectId,
  feature_category: :compliance_management,
  schema: 20240611142348 do
  include_examples 'desired sharding key backfill job' do
    let(:batch_table) { :status_check_responses }
    let(:backfill_column) { :project_id }
    let(:backfill_via_table) { :merge_requests }
    let(:backfill_via_column) { :target_project_id }
    let(:backfill_via_foreign_key) { :merge_request_id }
  end
end
