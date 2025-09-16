# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['AnalyzerGroupStatusType'], feature_category: :security_asset_inventories do
  let(:expected_fields) { %i[namespace_id analyzer_type success failure not_configured total_projects_count updatedAt] }

  subject { described_class }

  it { is_expected.to have_graphql_fields(expected_fields) }
end
