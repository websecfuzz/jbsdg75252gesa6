# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::BackfillResourceWeightEventsNamespaceId,
  feature_category: :team_planning,
  schema: 20241202142250 do
  include_examples 'desired sharding key backfill job' do
    let(:batch_table) { :resource_weight_events }
    let(:backfill_column) { :namespace_id }
    let(:backfill_via_table) { :issues }
    let(:backfill_via_column) { :namespace_id }
    let(:backfill_via_foreign_key) { :issue_id }
  end
end
