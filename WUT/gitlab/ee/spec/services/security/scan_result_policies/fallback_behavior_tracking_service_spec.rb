# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::FallbackBehaviorTrackingService, "#execute", feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let(:service) { described_class.new(merge_request) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be(:user) { create(:user) }
  let_it_be(:security_orchestration_policy_configuration) do
    create(:security_orchestration_policy_configuration, project: project)
  end

  let_it_be_with_refind(:project_rule) do
    create(
      :approval_project_rule,
      project: project,
      scanners: %w[dependency_scanning],
      approvals_required: 1)
  end

  let_it_be_with_refind(:rule) do
    create(
      :report_approver_rule,
      approval_project_rule: project_rule,
      scanners: %w[dependency_scanning],
      merge_request: merge_request,
      approvals_required: 0,
      users: [user])
  end

  subject(:execute) { service.execute }

  shared_context "with fallback behavior" do |fail_open|
    let(:behavior) { fail_open ? "open" : "closed" }

    before do
      rule.update!(scan_result_policy_read: create(:scan_result_policy_read,
        project: project,
        security_orchestration_policy_configuration: security_orchestration_policy_configuration,
        fallback_behavior: { fail: behavior }))
    end
  end

  shared_context "with invalid rule" do
    before do
      rule.update!(approvals_required: rule.approvers.size + 1)
    end
  end

  shared_context "with report" do
    let_it_be(:pipeline) do
      create(:ee_ci_pipeline,
        :success,
        :with_dependency_scanning_report,
        project: project,
        ref: merge_request.source_branch,
        merge_requests_as_head_pipeline: [merge_request])
    end

    let_it_be(:scan) do
      create(:security_scan, scan_type: 'dependency_scanning', pipeline: pipeline)
    end

    before do
      allow(project).to receive(:can_store_security_reports?).and_return(true)
    end
  end

  shared_context "with approvals remaining" do
    before do
      rule.update!(approvals_required: 1)
    end
  end

  shared_context "when not requiring approval" do
    before do
      project_rule.update!(approvals_required: 0)
    end
  end

  shared_examples "tracks internal event" do |expected|
    specify do
      if expected
        expect(Gitlab::InternalEvents).to receive(:track_event).with(
          described_class::EVENT_NAME,
          hash_including(project: project)
        ).and_call_original
      else
        expect(Gitlab::InternalEvents).not_to receive(:track_event)
      end

      execute
    end
  end

  shared_examples "tracks behavior" do |fail_open:, track_event:|
    context "when rule fails #{fail_open ? 'open' : 'closed'}" do
      include_context "with fallback behavior", fail_open
      it_behaves_like "tracks internal event", track_event
    end
  end

  shared_examples "tracks event" do |expected|
    include_examples "tracks behavior", fail_open: true, track_event: expected
    include_examples "tracks behavior", fail_open: false, track_event: false
  end

  context "with `scan_finding` rule" do
    before do
      rule.update!(report_type: :scan_finding)
    end

    context "with invalid rule" do
      include_context "with invalid rule"

      include_examples "tracks event", true
    end

    context "with missing report" do
      include_examples "tracks event", true
    end

    context "with report" do
      include_context "with report"

      include_examples "tracks event", false
    end

    context "with approvals remaining" do
      include_context "with approvals remaining"

      include_examples "tracks event", false
    end

    context "when not requiring approval" do
      include_context "when not requiring approval"

      include_examples "tracks event", false
    end

    context "when scan was removed" do
      include_context "with report"

      before do
        allow_next_instance_of(Security::ScanResultPolicies::UpdateApprovalsService) do |service|
          allow(service).to receive(:scan_removed?).with(rule).and_return(true)
        end
      end

      include_examples "tracks event", true
    end
  end

  context "with `license_scanning` rule" do
    before_all do
      rule.update!(report_type: :license_scanning)
    end

    context "with invalid rule" do
      include_context "with invalid rule"

      include_examples "tracks event", true
    end

    context "with missing report" do
      include_examples "tracks event", true
    end

    context "with report" do
      include_context "with report"

      include_examples "tracks event", false
    end

    context "with approvals remaining" do
      include_context "with approvals remaining"

      include_examples "tracks event", false
    end

    context "when not requiring approval" do
      include_context "when not requiring approval"

      include_examples "tracks event", false
    end
  end

  context "with `any_merge_request` rule" do
    before_all do
      rule.update!(report_type: :any_merge_request)
    end

    context "with invalid rule" do
      include_context "with invalid rule"

      include_examples "tracks event", true
    end

    context "with approvals remaining" do
      include_context "with approvals remaining"

      include_examples "tracks event", false
    end

    context "when not requiring approval" do
      include_context "when not requiring approval"

      include_examples "tracks event", false
    end
  end
end
