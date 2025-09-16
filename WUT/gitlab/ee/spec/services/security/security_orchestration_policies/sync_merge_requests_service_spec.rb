# frozen_string_literal: true

require "spec_helper"

RSpec.describe Security::SecurityOrchestrationPolicies::SyncMergeRequestsService, feature_category: :security_policy_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }
  let_it_be(:group_policy_configuration) do
    create(:security_orchestration_policy_configuration, project: nil, namespace: group)
  end

  let_it_be(:security_policy) do
    create(:security_policy, security_orchestration_policy_configuration: policy_configuration)
  end

  let_it_be(:approval_policy_rule) do
    create(:approval_policy_rule, security_policy: security_policy)
  end

  let_it_be(:container_scanning_project_approval_rule) do
    create(:approval_project_rule, :scan_finding,
      project: project,
      approval_policy_rule: approval_policy_rule,
      security_orchestration_policy_configuration: policy_configuration,
      scanners: %w[container_scanning]
    )
  end

  let_it_be(:sast_project_approval_rule) do
    create(:approval_project_rule, :scan_finding,
      project: project,
      approval_policy_rule: approval_policy_rule,
      security_orchestration_policy_configuration: policy_configuration,
      scanners: %w[sast]
    )
  end

  let_it_be(:project_approval_rule_from_group) do
    create(:approval_project_rule, :scan_finding,
      project: project,
      security_orchestration_policy_configuration: group_policy_configuration,
      scanners: %w[sast]
    )
  end

  let_it_be(:draft_merge_request) do
    create(:merge_request, :draft_merge_request, source_project: project, source_branch: "draft")
  end

  let_it_be(:opened_merge_request) { create(:merge_request, :opened, source_project: project) }
  let_it_be(:merged_merge_request) { create(:merge_request, :merged, source_project: project) }
  let_it_be(:closed_merge_request) { create(:merge_request, :closed, source_project: project) }

  let_it_be(:opened_mr_rule) do
    create(:report_approver_rule, :scan_finding,
      merge_request: opened_merge_request,
      approval_policy_rule: approval_policy_rule,
      security_orchestration_policy_configuration: policy_configuration
    )
  end

  let_it_be(:draft_mr_rule) do
    create(:report_approver_rule, :scan_finding,
      merge_request: draft_merge_request,
      approval_policy_rule: approval_policy_rule,
      security_orchestration_policy_configuration: policy_configuration
    )
  end

  before do
    create(:approval_merge_request_rule_source,
      approval_merge_request_rule: opened_mr_rule,
      approval_project_rule: container_scanning_project_approval_rule
    )
    create(:approval_merge_request_rule_source,
      approval_merge_request_rule: draft_mr_rule,
      approval_project_rule: container_scanning_project_approval_rule
    )
  end

  describe "#execute" do
    subject(:execute) { described_class.new(project: project, security_policy: security_policy).execute }

    context 'without head_pipeline for merge request' do
      it 'does not trigger workers' do
        expect(::Ci::SyncReportsToReportApprovalRulesWorker).not_to receive(:perform_async)
        expect(::Security::ScanResultPolicies::SyncFindingsToApprovalRulesWorker).not_to receive(:perform_async)

        execute
      end
    end

    describe 'fail-open rules' do
      it 'unblocks fail-open rules' do
        expect(::Security::ScanResultPolicies::UnblockFailOpenApprovalRulesWorker).to receive(:perform_async).twice

        execute
      end
    end

    context 'with head_pipeline' do
      let(:head_pipeline) { create(:ci_pipeline, project: project, ref: opened_merge_request.source_branch) }

      before do
        opened_merge_request.update!(head_pipeline_id: head_pipeline.id)
      end

      it 'triggers both workers' do
        expect(::Ci::SyncReportsToReportApprovalRulesWorker).to receive(:perform_async).with(head_pipeline.id)
        expect(::Security::ScanResultPolicies::SyncFindingsToApprovalRulesWorker)
          .to receive(:perform_async).with(head_pipeline.id)

        execute
      end
    end

    it "synchronizes rules to opened merge requests" do
      execute

      [opened_merge_request, draft_merge_request].each do |mr|
        expect(mr.approval_rules.scan_finding.count).to be(2)
      end
    end

    describe '#notify_for_policy_violations' do
      it 'enqueues UnenforceablePolicyRulesNotificationWorker' do
        expect(::Security::UnenforceablePolicyRulesNotificationWorker).to(
          receive(:perform_async).with(opened_merge_request.id, { 'force_without_approval_rules' => true })
        )
        expect(::Security::UnenforceablePolicyRulesNotificationWorker).to(
          receive(:perform_async).with(draft_merge_request.id, { 'force_without_approval_rules' => true })
        )

        execute
      end
    end

    context "when scan_result_policy_read targets commits" do
      let_it_be(:scan_result_policy_read) do
        create(:scan_result_policy_read, :targeting_commits, project: project,
          security_orchestration_policy_configuration: policy_configuration)
      end

      it "enqueues SyncAnyMergeRequestApprovalRulesWorker with opened merge requests" do
        expect(::Security::ScanResultPolicies::SyncAnyMergeRequestApprovalRulesWorker).to(
          receive(:perform_async).with(opened_merge_request.id)
        )
        expect(::Security::ScanResultPolicies::SyncAnyMergeRequestApprovalRulesWorker).to(
          receive(:perform_async).with(draft_merge_request.id)
        )

        execute
      end
    end

    context 'when merge request has scan_finding rules' do
      before do
        create(:approval_project_rule, :any_merge_request,
          project: project,
          approval_policy_rule: approval_policy_rule,
          security_orchestration_policy_configuration: policy_configuration
        )
      end

      it "enqueues SyncPreexistingStatesApprovalRulesWorker with opened merge requests" do
        expect(::Security::ScanResultPolicies::SyncPreexistingStatesApprovalRulesWorker).to(
          receive(:perform_async).with(opened_merge_request.id)
        )
        expect(::Security::ScanResultPolicies::SyncPreexistingStatesApprovalRulesWorker).to(
          receive(:perform_async).with(draft_merge_request.id)
        )

        execute
      end
    end

    it "does not synchronize rules to merged or closed requests" do
      execute

      [merged_merge_request, closed_merge_request].each do |mr|
        expect(mr.approval_rules.scan_finding.count).to be(0)
      end
    end

    it "does not synchronize rules of another policy configuration" do
      execute

      [opened_merge_request, draft_merge_request].each do |mr|
        expect(mr.approval_rules.map(&:approval_project_rule)).not_to include(project_approval_rule_from_group)
      end
    end

    context "when merge request is synchronized" do
      context "when fully synchronized" do
        it "does not alter rules" do
          expect { execute }.not_to change { opened_merge_request.approval_rules.map(&:attributes) }
        end
      end

      context "when partially synchronized" do
        before do
          opened_merge_request.approval_rules.reload.first.destroy!
        end

        it "creates missing rules" do
          expect { execute }.to change { opened_merge_request.approval_rules.count }.by(2)
        end
      end

      context "when project rule is dirty" do
        let(:states) { %w[detected confirmed] }
        let(:rule) { opened_merge_request.approval_rules.reload.last }

        before do
          sast_project_approval_rule.update_attribute(:vulnerability_states, states)
        end

        it "synchronizes the updated rule" do
          execute

          expect(rule.reload.vulnerability_states).to eq(states)
        end
      end
    end

    it_behaves_like 'policy metrics with logging', described_class::HISTOGRAM do
      let(:expected_logged_data) do
        {
          "class" => described_class.name,
          "duration" => kind_of(Float),
          "project_id" => project.id,
          "configuration_id" => policy_configuration.id
        }
      end
    end
  end
end
