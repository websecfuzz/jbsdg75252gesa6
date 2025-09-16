# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::SyncPreexistingStatesApprovalRulesService, feature_category: :security_policy_management do
  include RepoHelpers
  using RSpec::Parameterized::TableSyntax

  let_it_be(:project) { create(:project, :repository) }
  let(:service) { described_class.new(merge_request) }
  let_it_be(:merge_request, reload: true) do
    create(:ee_merge_request, :simple, source_project: project)
  end

  let_it_be(:scan_result_policy_read, reload: true) { create(:scan_result_policy_read, project: project) }
  let_it_be(:protected_branch) { create(:protected_branch, name: merge_request.target_branch, project: project) }

  before do
    stub_licensed_features(security_orchestration_policies: true)
  end

  describe '#execute' do
    subject(:execute) { service.execute }

    let(:approvals_required) { 1 }

    let!(:approval_project_rule) do
      create(:approval_project_rule, :scan_finding, project: project, approvals_required: approvals_required,
        scan_result_policy_read: scan_result_policy_read)
    end

    let!(:approver_rule) do
      create(:report_approver_rule, :scan_finding,
        merge_request: merge_request, vulnerability_states: ['detected'],
        approval_project_rule: approval_project_rule, approvals_required: approvals_required)
    end

    shared_examples_for 'does not update approval rules' do
      it 'does not update approval rules' do
        expect { execute }.not_to change { approver_rule.reload.approvals_required }
      end
    end

    shared_examples_for 'sets approvals_required to 0' do
      it 'sets approvals_required to 0' do
        expect { execute }.to change { approver_rule.reload.approvals_required }.to(0)
      end
    end

    shared_examples_for 'does not log violations' do
      it 'does not log violations' do
        expect(Gitlab::AppJsonLogger).not_to receive(:info)

        execute
      end
    end

    shared_examples_for 'logs only evaluation' do
      it 'logs the start of the evaluation' do
        expect(Gitlab::AppJsonLogger).to receive(:info).with(hash_including(
          message: 'Evaluating pre_existing scan_finding rules from approval policies'))

        execute
      end
    end

    context 'when merge_request is merged' do
      before do
        merge_request.update!(state: 'merged')
      end

      it_behaves_like 'does not update approval rules'
      it_behaves_like 'does not trigger policy bot comment'
      it_behaves_like 'does not log violations'
    end

    context 'when approvals are optional' do
      let(:approvals_required) { 0 }

      it_behaves_like 'does not update approval rules'
      it_behaves_like 'triggers policy bot comment', false
      it_behaves_like 'logs only evaluation'
    end

    context 'when rules do not contain pre-existing states' do
      let!(:approver_rule) do
        create(:report_approver_rule, :scan_finding, merge_request: merge_request,
          approval_project_rule: approval_project_rule, approvals_required: approvals_required,
          vulnerability_states: ['new_needs_triage']
        )
      end

      it_behaves_like 'does not update approval rules'
      it_behaves_like 'does not trigger policy bot comment'
      it_behaves_like 'merge request without scan result violations', previous_violation: false
      it_behaves_like 'does not log violations'
    end

    context 'when rules contain pre-existing states' do
      let!(:approver_rule) do
        create(:report_approver_rule, :scan_finding, merge_request: merge_request,
          approval_project_rule: approval_project_rule, approvals_required: approvals_required,
          vulnerability_states: ['detected'],
          scan_result_policy_read: scan_result_policy_read)
      end

      context 'with non-matching vulnerabilities and merge_request targeting non-default branch' do
        let_it_be(:vulnerabilities) do
          create_list(:vulnerability, 5, :with_finding,
            severity: :low,
            report_type: :sast,
            state: :resolved,
            project: project
          )
        end

        let_it_be(:merge_request, reload: true) do
          create(:ee_merge_request, :simple, source_project: project, source_branch: 'feature',
            target_branch: 'target')
        end

        before do
          create(:protected_branch, name: merge_request.target_branch, project: project)
        end

        it_behaves_like 'sets approvals_required to 0'
        it_behaves_like 'triggers policy bot comment', false
        it_behaves_like 'logs only evaluation'
        it_behaves_like 'merge request without scan result violations'
      end

      context 'when vulnerabilities count matches the pre-existing states' do
        let_it_be(:vulnerabilities) do
          create_list(:vulnerability, 5, :with_finding,
            severity: :low,
            report_type: :sast,
            state: :detected,
            project: project
          )
        end

        let(:uuids) { vulnerabilities.map(&:finding_uuid) }

        it_behaves_like 'does not update approval rules'
        it_behaves_like 'triggers policy bot comment', true

        it 'logs update' do
          expect(Gitlab::AppJsonLogger).to receive(:info).with(hash_including(
            message: 'Evaluating pre_existing scan_finding rules from approval policies'))
          expect(::Gitlab::AppJsonLogger)
            .to receive(:info).once.ordered
            .with(
              workflow: 'approval_policy_evaluation',
              event: 'update_approvals',
              message: 'Updating MR approval rule with pre_existing states',
              approval_rule_id: approver_rule.id,
              approval_rule_name: approver_rule.name,
              merge_request_id: merge_request.id,
              merge_request_iid: merge_request.iid,
              reason: 'pre_existing scan_finding rule violated',
              project_path: project.full_path
            ).and_call_original

          execute
        end

        it 'persists violation details', :aggregate_failures do
          execute

          violation_data = merge_request.scan_result_policy_violations.last.violation_data
          expect(violation_data)
            .to match({ 'violations' => { 'scan_finding' =>
              { 'uuids' => { 'previously_existing' => array_including(uuids) } } } })
          expect(violation_data.dig('violations', 'scan_finding', 'uuids', 'previously_existing'))
            .to match_array(uuids)
        end
      end

      context 'when vulnerabilities count does not match the pre-existing states' do
        it_behaves_like 'sets approvals_required to 0'
        it_behaves_like 'triggers policy bot comment', false
        it_behaves_like 'logs only evaluation'
        it_behaves_like 'merge request without scan result violations'

        context 'when there are other scan_finding violations' do
          let_it_be_with_reload(:scan_result_policy_read_other_scan_finding) do
            create(:scan_result_policy_read, project: project)
          end

          let_it_be(:approval_project_rule_other) do
            create(:approval_project_rule, :scan_finding, project: project, approvals_required: 1,
              scan_result_policy_read: scan_result_policy_read_other_scan_finding)
          end

          let_it_be(:approver_rule_other) do
            create(:report_approver_rule, :scan_finding,
              merge_request: merge_request, vulnerability_states: ['new_needs_triage'],
              approval_project_rule: approval_project_rule_other, approvals_required: 1,
              scan_result_policy_read: scan_result_policy_read_other_scan_finding)
          end

          let_it_be_with_reload(:other_violation) do
            create(:scan_result_policy_violation, scan_result_policy_read: scan_result_policy_read_other_scan_finding,
              merge_request: merge_request)
          end

          it_behaves_like 'triggers policy bot comment', true

          context 'when other violation has not been evaluated yet and has no data' do
            before do
              other_violation.update!(violation_data: nil)
            end

            it_behaves_like 'does not trigger policy bot comment'
          end
        end
      end
    end
  end
end
