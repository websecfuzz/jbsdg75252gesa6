# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::PolicyRuleEvaluationService, feature_category: :security_policy_management do
  let(:service) { described_class.new(merge_request) }
  let_it_be_with_reload(:project) { create(:project, :repository) }
  let_it_be(:merge_request, reload: true) do
    create(:merge_request, source_project: project, target_project: project)
  end

  let_it_be(:security_policy_project) { create(:project, :repository) }
  let_it_be_with_reload(:policy_configuration) do
    create(:security_orchestration_policy_configuration, project: project,
      security_policy_management_project: security_policy_project)
  end

  let_it_be(:protected_branch) do
    create(:protected_branch, name: merge_request.target_branch, project: project)
  end

  let_it_be(:policy_a, reload: true) do
    create(:scan_result_policy_read, project: project,
      security_orchestration_policy_configuration: policy_configuration, orchestration_policy_idx: 0, rule_idx: 0)
  end

  let_it_be(:policy_b) do
    create(:scan_result_policy_read, project: project,
      security_orchestration_policy_configuration: policy_configuration, orchestration_policy_idx: 1, rule_idx: 0)
  end

  let(:vulnerability_states) { %w[new_needs_triage new_dismissed] }
  let(:rule_scanners) { %w[dependency_scanning container_scanning] }
  let(:approval_project_rule_1) do
    create(:approval_project_rule, report_type, name: "Rule 1", project: project,
      approvals_required: 1,
      vulnerability_states: vulnerability_states,
      protected_branches: [protected_branch],
      scanners: rule_scanners,
      scan_result_policy_read: policy_a,
      security_orchestration_policy_configuration: policy_configuration)
  end

  let!(:approval_rule_1) do
    create(:report_approver_rule, report_type, name: "Rule 1", merge_request: merge_request,
      approvals_required: 1,
      approval_project_rule: approval_project_rule_1,
      vulnerability_states: vulnerability_states,
      scanners: rule_scanners,
      scan_result_policy_read: policy_a,
      security_orchestration_policy_configuration: policy_configuration)
  end

  let(:approval_project_rule_2) do
    create(:approval_project_rule, report_type, name: "Rule 2", project: project,
      approvals_required: 1,
      vulnerability_states: vulnerability_states,
      protected_branches: [protected_branch],
      scanners: rule_scanners,
      scan_result_policy_read: policy_b,
      security_orchestration_policy_configuration: policy_configuration)
  end

  let!(:approval_rule_2) do
    create(:report_approver_rule, report_type, name: "Rule 2", merge_request: merge_request,
      approvals_required: 1,
      approval_project_rule: approval_project_rule_2,
      vulnerability_states: vulnerability_states,
      scanners: rule_scanners,
      scan_result_policy_read: policy_b,
      security_orchestration_policy_configuration: policy_configuration)
  end

  let(:report_type) { :scan_finding }

  def violated_policies
    merge_request.scan_result_policy_violations.reload.map(&:scan_result_policy_read)
  end

  describe '#save' do
    subject(:execute) { service.save } # rubocop:disable Rails/SaveBang -- false positive

    describe '#fail!' do
      it 'creates violations for failed rules' do
        service.fail!(approval_rule_1)
        execute

        expect(violated_policies).to contain_exactly policy_a
      end

      it 'blocks the rule by resetting approvals' do
        approval_rule_1.update!(approvals_required: 0)
        service.fail!(approval_rule_1)

        expect { execute }.to change { approval_rule_1.reload.approvals_required }.to(1)
      end

      context 'when approval rule has no scan_result_policy_read' do
        it 'does not create violations' do
          approval_rule_1.update!(scan_result_policy_read: nil)
          approval_project_rule_1.update!(scan_result_policy_read: nil)
          service.fail!(approval_rule_1)

          expect { execute }.not_to change { violated_policies }
        end
      end
    end

    describe '#pass!' do
      before do
        create(:scan_result_policy_violation, project: project, merge_request: merge_request,
          scan_result_policy_read: policy_b)
      end

      it 'removes violations for passed rules' do
        service.pass!(approval_rule_2)
        execute

        expect(violated_policies).to be_empty
      end

      it 'unblocks the rule by removing required approvals' do
        service.pass!(approval_rule_2)
        expect { execute }.to change { approval_rule_2.reload.approvals_required }.to(0)
      end

      context 'when approval rule has no scan_result_policy_read' do
        it 'does not create violations' do
          approval_rule_2.update!(scan_result_policy_read: nil)
          approval_project_rule_2.update!(scan_result_policy_read: nil)
          service.pass!(approval_rule_2)

          expect { execute }.not_to change { violated_policies }
        end
      end
    end

    describe '#error!' do
      it 'adds violations for errored rules' do
        service.error!(approval_rule_1, :scan_removed, missing_scans: rule_scanners)
        execute

        expect(violated_policies).to contain_exactly policy_a
        violation = merge_request.scan_result_policy_violations.first
        expect(violation.violation_data)
          .to eq({ 'errors' => ['error' => 'SCAN_REMOVED', 'missing_scans' => rule_scanners] })
      end

      context 'when approval rule has no scan_result_policy_read' do
        it 'does not create violations' do
          approval_project_rule_1.update!(scan_result_policy_read: nil)
          approval_rule_1.update!(scan_result_policy_read: nil)
          service.error!(approval_rule_1, :scan_removed, missing_scans: rule_scanners)

          expect { execute }.not_to change { violated_policies }
        end
      end

      context 'when rule is excluded' do
        context 'when rule should fail open' do
          it 'creates a warning violation' do
            policy_a.update!(fallback_behavior: { fail: 'open' })
            service.error!(approval_rule_1, :scan_removed, missing_scans: rule_scanners)

            expect { execute }.to change { violated_policies.size }.by(1)
            expect(violated_policies).to contain_exactly policy_a
            expect(merge_request.scan_result_policy_violations.last).to be_warn
          end
        end

        shared_examples_for 'does not create a violation' do
          it 'does not create violations' do
            expect { execute_with_error }.not_to change { violated_policies }
            expect(violated_policies).to be_empty
          end
        end

        shared_examples_for 'creates a violation' do
          it 'creates violations' do
            execute_with_error

            expect(violated_policies).to contain_exactly policy_a
          end
        end

        shared_examples_for 'rule scanners enforced by execution policy' do
          let(:scans) { %w[dependency_scanning container_scanning] }
          let(:unblock_enabled) { true }

          subject(:execute_with_error) do
            service.error!(approval_rule_1, :scan_removed, missing_scans: rule_scanners)
            execute
          end

          before do
            policy_a.update!(policy_tuning: { unblock_rules_using_execution_policies: unblock_enabled })
            allow_next_instance_of(Repository) do |repository|
              allow(repository).to receive(:blob_data_at).and_return(policy_yaml)
            end
          end

          it_behaves_like 'does not create a violation'

          describe 'events' do
            subject { service.error!(approval_rule_1, :missing_artifacts, missing_scans: rule_scanners) }

            it_behaves_like 'internal event tracking' do
              let(:category) { described_class.name }
              let(:event) { 'unblock_approval_rule_using_scan_execution_policy' }
              let(:additional_properties) do
                {
                  label: 'dependency_scanning,container_scanning'
                }
              end
            end
          end

          context 'when the unblocking is not enabled by the policy' do
            let(:unblock_enabled) { false }

            it_behaves_like 'creates a violation'
          end

          context 'when rule has default vulnerability_states' do
            let(:vulnerability_states) { [] }

            it_behaves_like 'does not create a violation'
          end

          context 'when rule targets different scanners' do
            let(:rule_scanners) { %w[secret_detection] }

            it_behaves_like 'creates a violation'
          end

          context 'when rule is not excludable' do
            context 'when report is scan_finding' do
              let(:report_type) { :scan_finding }
              let(:vulnerability_states) { %w[detected] }

              it_behaves_like 'creates a violation'
            end

            context 'when report is license_scanning' do
              let(:report_type) { :license_scanning }

              before do
                policy_a.update!(license_states: ['detected'])
              end

              it_behaves_like 'creates a violation'
            end

            context 'when report is any_merge_request' do
              let(:report_type) { :any_merge_request }

              it_behaves_like 'creates a violation'
            end
          end
        end

        context 'with pipeline execution policies defined for the errored rule' do
          let(:pipeline_execution_policy) { build(:pipeline_execution_policy) }
          let(:policy_yaml) do
            build(:orchestration_policy_yaml, pipeline_execution_policy: [pipeline_execution_policy])
          end

          let(:policy_metadata) { { enforced_scans: scans } }
          let(:pipeline_execution_policy_configuration) { policy_configuration }

          before do
            create(:security_policy, :pipeline_execution_policy,
              security_orchestration_policy_configuration: pipeline_execution_policy_configuration,
              linked_projects: [project],
              metadata: policy_metadata)
          end

          include_context 'rule scanners enforced by execution policy'

          context 'when policy metadata is not present' do
            let(:policy_metadata) { {} }

            it_behaves_like 'creates a violation'
          end

          context 'when scans are enforced by both pipeline and scan execution policies' do
            let(:scans) { %w[dependency_scanning] }
            let(:scan_execution_policy) do
              build(:scan_execution_policy, actions: scan_execution_policy_scans.map { |scan| { scan: scan } })
            end

            let(:policy_yaml) do
              build(:orchestration_policy_yaml,
                pipeline_execution_policy: [pipeline_execution_policy],
                scan_execution_policy: [scan_execution_policy])
            end

            context 'when some scans are enforced by PEP and some by SEP' do
              let(:scan_execution_policy_scans) { %w[container_scanning] }

              it_behaves_like 'does not create a violation'
            end

            context 'when SEP enforces scans unrelated to the rule' do
              let(:scan_execution_policy_scans) { %w[secret_detection] }

              it_behaves_like 'creates a violation'
            end
          end

          context 'with group policies' do
            let_it_be(:parent_group) { create(:group) }
            let_it_be(:group) { create(:group, parent: parent_group) }

            before do
              project.update!(group: group)
            end

            context 'when policy is defined for a configuration in a group' do
              let_it_be(:pipeline_execution_policy_configuration) do
                create(:security_orchestration_policy_configuration, :namespace,
                  security_policy_management_project: security_policy_project, namespace: group)
              end

              it_behaves_like 'does not create a violation'
            end

            context 'when policy is defined for a configuration in a parent group' do
              let_it_be(:pipeline_execution_policy_configuration) do
                create(:security_orchestration_policy_configuration, :namespace,
                  security_policy_management_project: security_policy_project, namespace: parent_group)
              end

              it_behaves_like 'does not create a violation'
            end

            context 'when policy is defined for a configuration in a descendent group' do
              let_it_be(:descendent_group) { create(:group, parent: group) }
              let_it_be(:pipeline_execution_policy_configuration) do
                create(:security_orchestration_policy_configuration, :namespace,
                  security_policy_management_project: security_policy_project, namespace: descendent_group)
              end

              # NOTE: Approval rules belong to `group` config,
              # but pipeline execution policy is defined in the `descendant_group`.
              # Rules only get unblocked by ancestors of the configuration that created them.
              it_behaves_like 'creates a violation'
            end
          end
        end

        context 'with scan execution policies defined for the errored rule' do
          let(:scan_execution_policy) do
            build(:scan_execution_policy, actions: scans.map { |scan| { scan: scan } })
          end

          let(:policy_yaml) { build(:orchestration_policy_yaml, scan_execution_policy: [scan_execution_policy]) }

          include_context 'rule scanners enforced by execution policy'
        end
      end
    end

    describe '#skip!' do
      it 'adds violations for the skipped rules', :aggregate_failures do
        service.skip!(approval_rule_1)
        execute

        expect(violated_policies).to contain_exactly policy_a
        violation = merge_request.scan_result_policy_violations.first
        expect(violation).to be_skipped
        expect(violation.violation_data).to eq({ 'errors' => ['error' => 'EVALUATION_SKIPPED'] })
      end

      it 'blocks the rule by resetting approvals' do
        approval_rule_1.update!(approvals_required: 0)
        service.skip!(approval_rule_1)

        expect { execute }.to change { approval_rule_1.reload.approvals_required }.from(0).to(1)
      end

      context 'when approval rule has no scan_result_policy_read' do
        it 'does not create violations' do
          approval_project_rule_1.update!(scan_result_policy_read: nil)
          approval_rule_1.update!(scan_result_policy_read: nil)
          service.skip!(approval_rule_1)

          expect { execute }.not_to change { violated_policies }
        end
      end

      context 'when rule should fail open' do
        before do
          policy_b.update!(fallback_behavior: { fail: 'open' })
          service.skip!(approval_rule_2)
        end

        it 'adds warning violations for the skipped rules' do
          expect { execute }.to change { violated_policies.size }.from(0).to(1)
          violation = merge_request.scan_result_policy_violations.first
          expect(violation).to be_warn
          expect(violation.violation_data).to eq({ 'errors' => ['error' => 'EVALUATION_SKIPPED'] })
        end

        it 'unblocks the rule by removing required approvals' do
          expect { execute }.to change { approval_rule_2.reload.approvals_required }.from(1).to(0)
        end
      end
    end

    describe 'policy bot comment' do
      context 'with failing rules' do
        before do
          service.fail!(approval_rule_1)
          service.pass!(approval_rule_2)
        end

        it_behaves_like 'triggers policy bot comment', true
        it_behaves_like 'does not trigger policy bot comment for archived project' do
          let(:archived_project) { merge_request.project }
        end
      end

      context 'with passing rules' do
        before do
          service.pass!(approval_rule_1)
          service.pass!(approval_rule_2)
        end

        it_behaves_like 'triggers policy bot comment', false
        it_behaves_like 'does not trigger policy bot comment for archived project' do
          let(:archived_project) { merge_request.project }
        end
      end
    end
  end
end
