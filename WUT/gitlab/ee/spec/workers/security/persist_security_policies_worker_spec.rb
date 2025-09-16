# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PersistSecurityPoliciesWorker, '#perform', feature_category: :security_policy_management do
  include_context 'with approval policy' do
    let(:policy_configuration) { create(:security_orchestration_policy_configuration) }

    let(:policy_yaml) do
      build(
        :orchestration_policy_yaml,
        scan_execution_policy: scan_execution_policies,
        approval_policy: approval_policies,
        pipeline_execution_policy: pipeline_execution_policies,
        vulnerability_management_policy: vulnerability_management_policies,
        pipeline_execution_schedule_policy: pipeline_execution_schedule_policies
      )
    end

    let(:approval_policies) { build_list(:approval_policy, 2) + [build(:approval_policy, active: false)] }
    let(:scan_execution_policies) do
      build_list(:scan_execution_policy, 2) + [build(:scan_execution_policy, active: false)]
    end

    let(:pipeline_execution_policies) do
      build_list(:pipeline_execution_policy, 2) + [build(:pipeline_execution_policy, active: false)]
    end

    let(:pipeline_execution_schedule_policies) do
      build_list(:pipeline_execution_schedule_policy, 1) + [build(:pipeline_execution_schedule_policy, active: false)]
    end

    let(:vulnerability_management_policies) do
      build_list(:vulnerability_management_policy, 2) + [build(:vulnerability_management_policy, active: false)]
    end

    it_behaves_like 'an idempotent worker' do
      let(:params) { {} }
      subject(:perform) { perform_multiple([policy_configuration.id, params]) }

      context 'when policy is empty' do
        let(:approval_policies) { [] }
        let(:scan_execution_policies) { [] }
        let(:pipeline_execution_policies) { [] }
        let(:vulnerability_management_policies) { [] }
        let(:pipeline_execution_schedule_policies) { [] }

        it 'does not persist policies' do
          expect { perform }.not_to change { policy_configuration.security_policies.reload.count }
        end

        context 'when policy already exists in database' do
          before do
            create(:security_policy, security_orchestration_policy_configuration: policy_configuration)
          end

          it 'deletes the policy' do
            expect { perform }.to change { Security::Policy.count }.from(1).to(0)
          end
        end
      end

      context 'when force_resync is true' do
        let(:params) { { 'force_resync' => true } }

        it 'calls PersistPolicyService for each policy type with expected arguments' do
          [
            [policy_configuration.scan_result_policies, :approval_policy],
            [policy_configuration.scan_execution_policy, :scan_execution_policy],
            [policy_configuration.pipeline_execution_policy, :pipeline_execution_policy],
            [policy_configuration.vulnerability_management_policy, :vulnerability_management_policy],
            [policy_configuration.pipeline_execution_schedule_policy, :pipeline_execution_schedule_policy]
          ].each do |policies, policy_type|
            expect(Security::SecurityOrchestrationPolicies::PersistPolicyService)
              .to receive(:new)
                .exactly(IdempotentWorkerHelper::WORKER_EXEC_TIMES).with(
                  policy_configuration: policy_configuration,
                  policies: policies,
                  policy_type: policy_type,
                  force_resync: true
                ).and_call_original
          end

          perform
        end
      end

      describe 'cache eviction' do
        before do
          allow(Security::OrchestrationPolicyConfiguration)
            .to receive(:find_by_id).with(policy_configuration.id).and_return(policy_configuration)
          allow(Gitlab::AppJsonLogger).to receive(:debug)
        end

        it 'evicts policy cache' do
          expect(policy_configuration).to receive(:invalidate_policy_yaml_cache).at_least(:once)

          perform
        end
      end

      it 'persists approval policies' do
        perform

        expect(policy_configuration.security_policies.type_approval_policy.count).to be(3)
      end

      it 'persists scan execution policies' do
        perform

        expect(policy_configuration.security_policies.type_scan_execution_policy.count).to be(3)
      end

      it 'persists pipeline execution policies' do
        perform

        expect(policy_configuration.security_policies.type_pipeline_execution_policy.count).to be(3)
      end

      it 'persists vulnerability management policies' do
        perform

        expect(policy_configuration.security_policies.type_vulnerability_management_policy.count).to be(3)
      end

      it 'persists pipeline execution schedule policies' do
        perform

        expect(policy_configuration.security_policies.type_pipeline_execution_schedule_policy.count).to be(2)
      end

      it 'calls SyncScanResultPoliciesService' do
        expect_next_instance_of(
          Security::SecurityOrchestrationPolicies::SyncScanResultPoliciesService, policy_configuration
        ) do |service|
          expect(service).to receive(:execute).with(no_args)
        end.exactly(IdempotentWorkerHelper::WORKER_EXEC_TIMES)

        perform
      end

      it 'calls CollectPoliciesLimitAuditEventsWorker' do
        expect(Security::CollectPoliciesLimitAuditEventsWorker).to receive(:perform_async)
          .with(policy_configuration.id).exactly(IdempotentWorkerHelper::WORKER_EXEC_TIMES)

        perform
      end

      context 'if the collect_policies_limit_audit_events feature is disabled' do
        before do
          stub_feature_flags(collect_policies_limit_audit_events: false)
        end

        it 'persists policies' do
          expect { perform }.to change { policy_configuration.security_policies.count }
        end

        it 'does not call CollectPoliciesLimitAuditEventsWorker' do
          expect(Security::CollectPoliciesLimitAuditEventsWorker).not_to receive(:perform_async)

          perform
        end
      end
    end

    describe 'CSP usage tracking' do
      subject(:perform) { described_class.new.perform(policy_configuration.id) }

      context 'when configuration does not belongs to a CSP group' do
        it_behaves_like 'internal event not tracked'
      end

      context 'when configuration belongs to a CSP group' do
        include_context 'with csp group configuration'

        let(:policy_configuration) { csp_security_orchestration_policy_configuration }

        it_behaves_like 'internal event tracking' do
          let(:category) { described_class }
          let(:event) { 'sync_csp_configuration' }
          let(:namespace) { csp_group }
        end
      end
    end
  end
end
