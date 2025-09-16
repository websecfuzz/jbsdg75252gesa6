# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::CountProjectsWithAppliedScanResultPoliciesMetric, feature_category: :security_policy_management do
  let_it_be(:old_scan_finding_approval_project_rule) do
    create(:approval_project_rule, :scan_finding, created_at: 2.months.ago)
  end

  let_it_be(:scan_finding_approval_project_rule) do
    create(:approval_project_rule, :scan_finding, created_at: 25.days.ago)
  end

  let_it_be(:license_scanning_approval_project_rule) do
    create(:approval_project_rule, :license_scanning, created_at: 25.days.ago)
  end

  let_it_be(:any_merge_request_approval_project_rule) do
    create(:approval_project_rule, :any_merge_request, created_at: 2.months.ago)
  end

  let_it_be(:code_coverage_approval_project_rule) do
    create(:approval_project_rule, :code_coverage, created_at: 25.days.ago)
  end

  it_behaves_like 'a correct instrumented metric value and query', { time_frame: 'all', data_source: 'database' } do
    let(:expected_value) { 4 }
    let(:expected_query) do
      'SELECT COUNT(DISTINCT "approval_project_rules"."project_id") FROM "approval_project_rules" ' \
        'WHERE "approval_project_rules"."report_type" IN (4, 2, 5)'
    end
  end

  it_behaves_like 'a correct instrumented metric value and query', { time_frame: '28d', data_source: 'database' } do
    let(:expected_value) { 2 }
    let(:start) { 30.days.ago.to_fs(:db) }
    let(:finish) { 2.days.ago.to_fs(:db) }
    let(:expected_query) do
      "SELECT COUNT(DISTINCT \"approval_project_rules\".\"project_id\") FROM \"approval_project_rules\" " \
        "WHERE \"approval_project_rules\".\"report_type\" IN (4, 2, 5) " \
        "AND \"approval_project_rules\".\"created_at\" BETWEEN '#{start}' AND '#{finish}'"
    end
  end
end
