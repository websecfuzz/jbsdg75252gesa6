# frozen_string_literal: true

require "spec_helper"

RSpec.describe Security::SecurityOrchestrationPolicies::SyncScanResultPoliciesService, feature_category: :security_policy_management do
  let_it_be(:configuration, refind: true) { create(:security_orchestration_policy_configuration, configured_at: nil) }

  let(:service) { described_class.new(configuration) }

  describe '#execute' do
    subject(:execute) { service.execute }

    context 'with configuration at group level and with delay' do
      let_it_be(:namespace) { create(:namespace) }
      let_it_be(:configuration, refind: true) do
        create(:security_orchestration_policy_configuration, namespace: namespace, project: nil, configured_at: nil)
      end

      let_it_be(:project1) { create(:project, namespace: namespace) }
      let_it_be(:project2) { create(:project, namespace: namespace) }
      let_it_be(:project3) { create(:project, namespace: namespace) }

      let(:sync_project_service) do
        instance_double(Security::SecurityOrchestrationPolicies::SyncScanResultPoliciesProjectService)
      end

      before do
        allow(Security::SecurityOrchestrationPolicies::SyncScanResultPoliciesProjectService).to receive(:new)
          .and_return(sync_project_service)

        stub_const("Security::OrchestrationPolicyConfiguration::ALL_PROJECT_IDS_BATCH_SIZE", 1)
      end

      it 'increases delay by 10 seconds for each batch',
        quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/524382' do
        expect(sync_project_service).to receive(:execute).with(project1.id, { delay: 0.seconds })
        expect(sync_project_service).to receive(:execute).with(project2.id, { delay: 10.seconds })
        expect(sync_project_service).to receive(:execute).with(project3.id, { delay: 20.seconds })

        service.execute
      end
    end

    it 'triggers worker for the configuration' do
      expect_next_instance_of(
        Security::SecurityOrchestrationPolicies::SyncScanResultPoliciesProjectService,
        configuration
      ) do |sync_service|
        expect(sync_service).to receive(:execute).with(configuration.project_id, { delay: 0 })
      end

      execute
    end

    context 'with namespace association' do
      let_it_be(:namespace) { create(:namespace) }
      let_it_be(:project) { create(:project, namespace: namespace) }
      let_it_be(:configuration, refind: true) do
        create(:security_orchestration_policy_configuration, configured_at: nil, project: nil, namespace: namespace)
      end

      it 'triggers SyncScanResultPoliciesProjectService for the configuration and project_id' do
        expect_next_instance_of(
          Security::SecurityOrchestrationPolicies::SyncScanResultPoliciesProjectService,
          configuration
        ) do |sync_service|
          expect(sync_service).to receive(:execute).with(project.id, { delay: 0 })
        end

        execute
      end

      context 'with multiple projects in the namespace' do
        let_it_be(:worker) { Security::ProcessScanResultPolicyWorker }

        it 'does trigger SyncScanResultPoliciesProjectService for each project in group' do
          create_list(:project, 2, namespace: namespace)

          expect(worker).to receive(:perform_in).and_call_original.exactly(3).times

          execute
        end
      end
    end

    describe 'metrics' do
      specify do
        hist = Security::SecurityOrchestrationPolicies::ObserveHistogramsService
          .histogram(:gitlab_security_policies_update_configuration_duration_seconds)

        expect(hist)
          .to receive(:observe).with({}, kind_of(Float)).and_call_original

        execute
      end
    end
  end
end
