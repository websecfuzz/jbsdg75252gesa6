# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::BackfillIssueMetricsNamespaceId,
  feature_category: :value_stream_management,
  schema: 20241203074400 do
  include_examples 'desired sharding key backfill job' do
    let(:batch_table) { :issue_metrics }
    let(:backfill_column) { :namespace_id }
    let(:backfill_via_table) { :issues }
    let(:backfill_via_column) { :namespace_id }
    let(:backfill_via_foreign_key) { :issue_id }
  end
end
