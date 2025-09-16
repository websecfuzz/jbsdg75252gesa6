# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::UpdateViolationsService, feature_category: :security_policy_management do
  let(:service) { described_class.new(merge_request) }
  let_it_be(:project) { create(:project) }
  let_it_be(:merge_request, reload: true) do
    create(:merge_request, source_project: project, target_project: project)
  end

  let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }

  let_it_be(:security_policy_a) do
    create(:security_policy, security_orchestration_policy_configuration: policy_configuration, policy_index: 0)
  end

  let_it_be(:security_policy_b) do
    create(:security_policy, security_orchestration_policy_configuration: policy_configuration, policy_index: 1)
  end

  let_it_be(:policy_a, reload: true) do
    create(:scan_result_policy_read, project: project,
      security_orchestration_policy_configuration: policy_configuration, orchestration_policy_idx: 0, rule_idx: 0)
  end

  let_it_be(:policy_b) do
    create(:scan_result_policy_read, project: project,
      security_orchestration_policy_configuration: policy_configuration, orchestration_policy_idx: 1, rule_idx: 0)
  end

  let_it_be(:approval_policy_rule_a) do
    create(:approval_policy_rule, security_policy: security_policy_a, rule_index: 0)
  end

  let_it_be(:approval_policy_rule_b) do
    create(:approval_policy_rule, security_policy: security_policy_b, rule_index: 0)
  end

  let(:violated_policies) { violations.map(&:scan_result_policy_read) }

  subject(:violations) { merge_request.scan_result_policy_violations }

  def last_violation
    violations.last.reload
  end

  describe '#execute' do
    describe 'attributes' do
      subject(:attrs) { project.scan_result_policy_violations.last.attributes }

      before do
        service.add([policy_a], [])
        service.execute
      end

      specify do
        is_expected.to include(
          "scan_result_policy_id" => policy_a.id,
          "merge_request_id" => merge_request.id,
          "project_id" => project.id,
          "approval_policy_rule_id" => approval_policy_rule_a.id
        )
      end
    end

    context 'without pre-existing violations' do
      before do
        service.add([policy_b], [])
      end

      it 'creates violations' do
        service.execute

        expect(violated_policies).to contain_exactly(policy_b)
        expect(last_violation.approval_policy_rule).to eq(approval_policy_rule_b)
      end

      it 'stores the correct status' do
        service.add_violation(policy_b, :scan_finding, { uuid: { newly_detected: [123] } })
        service.execute

        expect(last_violation.status).to eq('failed')
        expect(last_violation).to be_valid
      end

      it 'can persist violation data' do
        service.add_violation(policy_b, :scan_finding, { uuid: { newly_detected: [123] } })
        service.execute

        expect(last_violation.violation_data)
          .to eq({ "violations" => { "scan_finding" => { "uuid" => { "newly_detected" => [123] } } } })
        expect(last_violation).to be_valid
      end

      it 'publishes MergeRequests::ViolationsUpdatedEvent' do
        expect { service.execute }
          .to publish_event(::MergeRequests::ViolationsUpdatedEvent)
          .with(merge_request_id: merge_request.id)
      end

      context 'when policy_mergability_check is off' do
        before do
          stub_feature_flags(policy_mergability_check: false)
        end

        it 'does not publish MergeRequests::ViolationsUpdatedEvent' do
          expect { service.execute }.not_to publish_event(MergeRequests::ViolationsUpdatedEvent)
        end
      end
    end

    context 'with pre-existing violations' do
      before do
        service.add_violation(policy_a, :scan_finding, { uuids: { newly_detected: [123] } })
        service.execute
      end

      it 'clears existing violations' do
        service.add([policy_b], [policy_a])
        service.execute

        expect(violated_policies).to contain_exactly(policy_b)
        expect(last_violation.approval_policy_rule).to eq(approval_policy_rule_b)
      end

      it 'can add error to existing violation data' do
        service.add_error(policy_a, :scan_removed, missing_scans: ['sast'])

        expect { service.execute }
          .to change { last_violation.violation_data }.to match(
            { 'violations' => { 'scan_finding' => { 'uuids' => { 'newly_detected' => [123] } } },
              'errors' => [{ 'error' => 'SCAN_REMOVED', 'missing_scans' => ['sast'] }] }
          )
        expect(last_violation).to be_valid
      end

      it 'stores the correct status' do
        service.add_error(policy_a, :scan_removed, missing_scans: ['sast'])
        service.execute

        expect(last_violation.status).to eq('failed')
        expect(last_violation).to be_valid
      end

      context 'with identical state' do
        it 'does not clear violations' do
          service.add([policy_a], [])

          expect { service.execute }.not_to change { last_violation.violation_data }
          expect(violated_policies).to contain_exactly(policy_a)
          expect(last_violation).to be_valid
        end
      end
    end

    context 'with unrelated existing violation' do
      let_it_be(:unrelated_violation) do
        create(:scan_result_policy_violation, scan_result_policy_read: policy_a, merge_request: merge_request)
      end

      before do
        service.add([], [policy_b])
      end

      it 'removes only violations provided in unviolated ids' do
        service.execute

        expect(violations).to contain_exactly(unrelated_violation)
      end

      it 'publishes MergeRequests::ViolationsUpdatedEvent' do
        expect { service.execute }
          .to publish_event(::MergeRequests::ViolationsUpdatedEvent)
          .with(merge_request_id: merge_request.id)
      end

      context 'when policy_mergability_check is off' do
        before do
          stub_feature_flags(policy_mergability_check: false)
        end

        it 'does not publish MergeRequests::ViolationsUpdatedEvent' do
          expect { service.execute }.not_to publish_event(MergeRequests::ViolationsUpdatedEvent)
        end
      end
    end

    context 'without violations' do
      it 'clears all violations' do
        service.execute

        expect(violations).to be_empty
      end

      it 'does not publish MergeRequests::ViolationsUpdatedEvent' do
        expect { service.execute }.not_to publish_event(MergeRequests::ViolationsUpdatedEvent)
      end
    end

    describe 'policy_violations_detected audit event' do
      shared_examples 'not enqueuing the PolicyViolationsDetectedAuditEventWorker' do
        it 'does not enqueue MergeRequests::PolicyViolationsDetectedAuditEventWorker' do
          expect(::MergeRequests::PolicyViolationsDetectedAuditEventWorker).not_to receive(:perform_async)

          service.execute
        end
      end

      context 'when there are policy violations' do
        before do
          service.add([policy_a], [])
          service.execute
        end

        it 'enqueues MergeRequests::PolicyViolationsDetectedAuditEventWorker' do
          expect(::MergeRequests::PolicyViolationsDetectedAuditEventWorker).to receive(:perform_async).with(
            merge_request.id
          )

          service.execute
        end
      end

      context "when there are running violations" do
        let_it_be(:running_violation) do
          create(:scan_result_policy_violation, :running, scan_result_policy_read: policy_a,
            merge_request: merge_request)
        end

        let_it_be(:failed_violation) do
          create(:scan_result_policy_violation, :failed, scan_result_policy_read: policy_b,
            merge_request: merge_request)
        end

        it_behaves_like 'not enqueuing the PolicyViolationsDetectedAuditEventWorker'
      end

      context "when there are no violations" do
        it_behaves_like 'not enqueuing the PolicyViolationsDetectedAuditEventWorker'
      end

      context 'when feature flag is disabled' do
        before do
          stub_feature_flags(collect_security_policy_violations_detected_audit_events: false)
        end

        it_behaves_like 'not enqueuing the PolicyViolationsDetectedAuditEventWorker'
      end
    end

    describe 'policy_violations_resolved audit event' do
      shared_examples 'not enqueuing the PolicyViolationsResolvedAuditEventWorker' do
        it 'does not enqueue MergeRequests::PolicyViolationsResolvedAuditEventWorker' do
          expect(::MergeRequests::PolicyViolationsResolvedAuditEventWorker).not_to receive(:perform_async)

          service.execute
        end
      end

      context 'when violations with data are removed' do
        let_it_be(:existing_violation) do
          create(:scan_result_policy_violation, :failed, merge_request: merge_request, project: project,
            scan_result_policy_read: policy_a, violation_data: { any_merge_request: { commits: true } })
        end

        before do
          service.remove_violation(policy_a)
        end

        context 'when there are no other existing violations' do
          it 'enqueues MergeRequests::PolicyViolationsResolvedAuditEventWorker' do
            expect(::MergeRequests::PolicyViolationsResolvedAuditEventWorker).to receive(:perform_async).with(
              merge_request.id
            )

            service.execute
          end
        end

        context 'when there are other existing violations' do
          before do
            service.add([policy_b], [])
          end

          it_behaves_like 'not enqueuing the PolicyViolationsResolvedAuditEventWorker'
        end

        context 'when the feature flag is disabled' do
          before do
            stub_feature_flags(collect_security_policy_violations_resolved_audit_events: false)
          end

          it_behaves_like 'not enqueuing the PolicyViolationsResolvedAuditEventWorker'
        end
      end

      context 'when violations without data are removed' do
        before do
          create(:scan_result_policy_violation, :running, merge_request: merge_request, project: project,
            scan_result_policy_read: policy_a, violation_data: nil)

          service.remove_violation(policy_a)
        end

        it_behaves_like 'not enqueuing the PolicyViolationsResolvedAuditEventWorker'
      end
    end
  end

  describe '#add_violation' do
    subject(:violation_data) do
      service.add_violation(policy_a, :scan_finding, data, context: context)
      service.violation_data[policy_a.id]
    end

    let(:context) { nil }
    let(:data) { { uuid: { newly_detected: [123] } } }

    it 'adds violation data into the correct structure' do
      expect(violation_data)
        .to eq({ violations: { scan_finding: { uuid: { newly_detected: [123] } } } })
    end

    it 'stores the correct status' do
      service.add_violation(policy_a, :scan_finding, data, context: context)
      service.execute

      expect(last_violation.status).to eq('failed')
      expect(last_violation).to be_valid
    end

    context 'when policy is fail-open' do
      before do
        policy_a.update!(fallback_behavior: { fail: 'open' })
      end

      it 'persists the violation as failed', :aggregate_failures do
        service.add_violation(policy_a, :scan_finding, data, context: context)
        service.execute

        expect(last_violation.status).to eq('failed')
      end
    end

    context 'when other data is present' do
      before do
        service.add_violation(policy_a, :scan_finding, { uuid: { previously_existing: [456] } })
      end

      it 'merges the data for report_type' do
        expect(violation_data)
          .to eq({ violations: { scan_finding: { uuid: { previously_existing: [456], newly_detected: [123] } } } })
      end
    end

    context 'with additional context' do
      let(:context) { { pipeline_ids: [1] } }

      it 'saves context information' do
        expect(violation_data)
          .to match({
            context: { pipeline_ids: [1] },
            violations: { scan_finding: { uuid: { newly_detected: [123] } } }
          })
      end
    end
  end

  describe '#remove_violation' do
    subject(:remove_violation) do
      service.remove_violation(policy_a)
      service.execute
    end

    let!(:existing_violation) do
      create(:scan_result_policy_violation, merge_request: merge_request, project: project,
        scan_result_policy_read: policy_a)
    end

    it 'removes violation for the policy' do
      expect { remove_violation }.to change { merge_request.scan_result_policy_violations.count }.from(1).to(0)
    end
  end

  describe '#add_error' do
    subject(:violation_data) do
      service.add_error(policy_a, error, context: context, **extra_data)
      service.violation_data[policy_a.id]
    end

    let(:error) { :scan_removed }
    let(:extra_data) { {} }
    let(:context) { nil }

    it 'adds error into violation data and persists the violation as failed', :aggregate_failures do
      expect(violation_data)
        .to eq({ errors: [{ error: 'SCAN_REMOVED' }] })
      service.execute
      expect(last_violation.status).to eq('failed')
    end

    context 'when policy is fail-open' do
      before do
        policy_a.update!(fallback_behavior: { fail: 'open' })
      end

      it 'persists the violation as warning', :aggregate_failures do
        expect(violation_data)
          .to eq({ errors: [{ error: 'SCAN_REMOVED' }] })
        service.execute
        expect(last_violation.status).to eq('warn')
      end
    end

    context 'when other error is present' do
      before do
        service.add_error(policy_a, :artifacts_missing)
      end

      it 'merges the errors' do
        expect(violation_data)
          .to match({ errors: array_including({ error: 'SCAN_REMOVED' }, { error: 'ARTIFACTS_MISSING' }) })
      end
    end

    context 'with extra data' do
      let(:extra_data) { { missing_scans: ['sast'] } }

      it 'saves extra data' do
        expect(violation_data)
          .to eq({ errors: [{ error: 'SCAN_REMOVED', missing_scans: ['sast'] }] })
      end
    end

    context 'with context' do
      let(:context) { { pipeline_ids: [1999], target_pipeline_ids: [2000] } }

      it 'adds context into violation data' do
        expect(violation_data)
          .to eq({ errors: [{ error: 'SCAN_REMOVED' }],
                   context: { pipeline_ids: [1999], target_pipeline_ids: [2000] } })
      end
    end
  end

  describe '#skip' do
    it 'adds a specific error into violation data and persists the violation as skipped', :aggregate_failures do
      service.skip(policy_a)
      service.execute

      expect(violated_policies).to contain_exactly(policy_a)
      expect(last_violation).to be_skipped
      expect(last_violation.violation_data).to match(
        { 'errors' => [{ 'error' => 'EVALUATION_SKIPPED' }] }
      )
    end

    context 'when policy is fail-open' do
      before do
        policy_a.update!(fallback_behavior: { fail: 'open' })
      end

      it 'persists the violation as warning', :aggregate_failures do
        service.skip(policy_a)
        service.execute

        expect(violated_policies).to contain_exactly(policy_a)
        expect(last_violation).to be_warn
        expect(last_violation.violation_data).to match(
          { 'errors' => [{ 'error' => 'EVALUATION_SKIPPED' }] }
        )
      end
    end

    context 'when other error is present for a skipped policy' do
      it 'merges the errors and persists it as failed', :aggregate_failures do
        service.skip(policy_a)
        service.add_error(policy_a, :artifacts_missing)
        service.execute

        expect(violated_policies).to contain_exactly(policy_a)
        expect(last_violation).to be_failed
        expect(last_violation.violation_data).to match(
          { 'errors' => array_including({ 'error' => 'ARTIFACTS_MISSING' }, { 'error' => 'EVALUATION_SKIPPED' }) }
        )
      end
    end
  end
end
