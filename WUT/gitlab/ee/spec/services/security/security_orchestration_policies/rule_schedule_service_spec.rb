# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::RuleScheduleService, feature_category: :security_policy_management do
  describe '#execute' do
    let(:project) { create(:project, :repository) }
    let(:current_user) { project.users.first }
    let(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }
    let(:schedule) { create(:security_orchestration_policy_rule_schedule, security_orchestration_policy_configuration: policy_configuration) }
    let!(:scanner_profile) { create(:dast_scanner_profile, name: 'Scanner Profile', project: project) }
    let!(:site_profile) { create(:dast_site_profile, name: 'Site Profile', project: project) }
    let(:policy) { build(:scan_execution_policy, enabled: true, rules: [rule, pipeline_rule, other_schedule_rule]) }
    let(:pipeline_rule) { { type: 'pipeline', branches: ['develop'] } }
    let(:rule) { { type: 'schedule', branches: branches, cadence: '*/20 * * * *' } }
    let(:other_schedule_rule) { { type: 'schedule', branches: ['main'], cadence: '0 10 * * *' } }
    let(:branches) { %w[master production non-existing-branch] }
    let(:existing_branches) { %w[master production] }

    subject(:service) { described_class.new(project: project, current_user: current_user) }

    shared_examples 'does not enqueue Security::ScanExecutionPolicies::CreatePipelineWorker' do
      it 'does not enqueue Security::ScanExecutionPolicies::CreatePipelineWorker' do
        expect(::Security::ScanExecutionPolicies::CreatePipelineWorker).not_to receive(:perform_async)

        service.execute(schedule)
      end
    end

    before do
      stub_licensed_features(security_on_demand_scans: true)

      project.repository.create_branch('production', project.default_branch)

      allow_next_instance_of(Security::OrchestrationPolicyConfiguration) do |instance|
        allow(instance).to receive(:active_scan_execution_policies).and_return([policy])
      end
    end

    it 'returns a successful service response' do
      service_result = service.execute(schedule)

      expect(service_result).to be_kind_of(ServiceResponse)
      expect(service_result.success?).to be(true)
    end

    shared_examples 'enqueues Security::ScanExecutionPolicies::CreatePipelineWorker for each branch' do
      it 'enqueues Security::ScanExecutionPolicies::CreatePipelineWorker for each branch' do
        existing_branches.each do |branch|
          expect(::Security::ScanExecutionPolicies::CreatePipelineWorker).to(
            receive(:perform_async)
              .with(project.id, current_user.id, schedule.id, branch)
              .and_call_original
          )
        end

        service.execute(schedule)
      end

      context 'when the time_window is available' do
        before do
          policy[:rules].first.merge!({ time_window: { distribution: 'random', value: 3600 } })
        end

        it 'enqueues Security::ScanExecutionPolicies::CreatePipelineWorker for each branch with a random delay' do
          existing_branches.each do |branch|
            expect(::Security::ScanExecutionPolicies::CreatePipelineWorker).to(
              receive(:perform_in)
                .with(ActiveSupport::Duration, project.id, current_user.id, schedule.id, branch)
                .and_call_original
            )
          end

          service.execute(schedule)
        end
      end
    end

    context 'when scan type is dast' do
      before do
        policy[:actions] = [{ scan: 'dast' }]
      end

      it_behaves_like 'enqueues Security::ScanExecutionPolicies::CreatePipelineWorker for each branch'
    end

    context 'when scan type is secret_detection' do
      before do
        policy[:actions] = [{ scan: 'secret_detection' }]
      end

      it_behaves_like 'enqueues Security::ScanExecutionPolicies::CreatePipelineWorker for each branch'
    end

    context 'when scan type is container_scanning' do
      before do
        policy[:actions] = [{ scan: 'container_scanning' }]
      end

      context 'when clusters are not defined in the rule' do
        it_behaves_like 'enqueues Security::ScanExecutionPolicies::CreatePipelineWorker for each branch'
      end

      context 'when agents are defined in the rule' do
        let(:rule) { { type: 'schedule', agents: { kasagent: { namespaces: 'default' } }, cadence: '*/20 * * * *' } }

        it_behaves_like 'does not enqueue Security::ScanExecutionPolicies::CreatePipelineWorker'
      end
    end

    context 'when scan type is sast' do
      before do
        policy[:actions] = [{ scan: 'sast' }]
      end

      it_behaves_like 'enqueues Security::ScanExecutionPolicies::CreatePipelineWorker for each branch'
    end

    context 'when policy actions exists and there are multiple matching branches' do
      it_behaves_like 'enqueues Security::ScanExecutionPolicies::CreatePipelineWorker for each branch'
    end

    context 'without rules' do
      before do
        policy.delete(:rules)
      end

      subject(:response) { service.execute(schedule) }

      it_behaves_like 'does not enqueue Security::ScanExecutionPolicies::CreatePipelineWorker'

      it 'fails' do
        expect(response.to_h).to include(status: :error, message: "No rules")
      end
    end

    context 'without scheduled rules' do
      before do
        policy[:rules] = [{ type: 'pipeline', branches: [] }]
      end

      subject(:response) { service.execute(schedule) }

      it_behaves_like 'does not enqueue Security::ScanExecutionPolicies::CreatePipelineWorker'

      it 'fails' do
        expect(response.to_h).to include(status: :error, message: "No scheduled rules")
      end
    end

    context 'with mismatching `branches`' do
      let(:policy) do
        build(
          :scan_execution_policy,
          enabled: true,
          rules: [{ type: 'schedule', branches: %w[invalid_branch], cadence: '*/20 * * * *' }]
        )
      end

      it_behaves_like 'does not enqueue Security::ScanExecutionPolicies::CreatePipelineWorker'
    end

    context 'with mismatching `branch_type`' do
      let(:policy) do
        build(
          :scan_execution_policy,
          enabled: true,
          rules: [{ type: 'schedule', branch_type: "protected", cadence: '*/20 * * * *' }]
        )
      end

      it_behaves_like 'does not enqueue Security::ScanExecutionPolicies::CreatePipelineWorker'
    end

    context 'when policy actions does not exist' do
      let(:policy) { build(:scan_execution_policy, :with_schedule, enabled: true, actions: []) }

      it_behaves_like 'does not enqueue Security::ScanExecutionPolicies::CreatePipelineWorker'
    end

    context 'when policy scan type is invalid' do
      let(:policy) { build(:scan_execution_policy, :with_schedule, enabled: true, actions: [{ scan: 'invalid' }]) }

      it 'enqueues Security::ScanExecutionPolicies::CreatePipelineWorker' do
        expect(::Security::ScanExecutionPolicies::CreatePipelineWorker)
          .to(receive(:perform_async))
          .with(project.id, current_user.id, schedule.id, project.default_branch)
          .and_call_original

        service.execute(schedule)
      end
    end

    context 'when policy does not exist' do
      let(:policy) { nil }

      it_behaves_like 'does not enqueue Security::ScanExecutionPolicies::CreatePipelineWorker'
    end

    describe "branch lookup" do
      let(:policy) do
        build(
          :scan_execution_policy,
          enabled: true,
          rules: [{ type: 'schedule', branch_type: "protected", cadence: '*/20 * * * *' }]
        )
      end

      before do
        project.protected_branches.create!(name: project.default_branch)
      end

      it 'enqueues Security::ScanExecutionPolicies::CreatePipelineWorker' do
        expect(::Security::ScanExecutionPolicies::CreatePipelineWorker)
          .to(receive(:perform_async))
          .with(project.id, current_user.id, schedule.id, project.default_branch)
          .and_call_original

        service.execute(schedule)
      end
    end
  end
end
