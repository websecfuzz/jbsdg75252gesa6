# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanExecutionPolicies::CreatePipelineWorker, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:security_orchestration_policy_configuration) do
    create(:security_orchestration_policy_configuration, project: project)
  end

  let_it_be(:schedule) do
    create(:security_orchestration_policy_rule_schedule,
      security_orchestration_policy_configuration: security_orchestration_policy_configuration)
  end

  let(:project_id) { project.id }
  let(:current_user_id) { current_user.id }
  let(:branch) { 'production' }
  let(:actions) { [{ scan: 'dast' }] }
  let(:params) { { actions: actions, branch: branch } }
  let(:schedule_id) { schedule.id }
  let(:policy) { build(:scan_execution_policy, enabled: true, actions: [{ scan: 'dast' }]) }

  shared_examples_for 'does not call CreatePipelineService' do
    it do
      expect(Security::SecurityOrchestrationPolicies::CreatePipelineService).not_to receive(:new)

      run_worker
    end
  end

  shared_examples_for 'tracks scheduled_scan_execution metrics' do |scan_count, policy_source, time_window|
    it 'tracks internal metrics with the right parameters' do
      expect { run_worker }.to trigger_internal_events('enforce_scheduled_scan_execution_policy_in_project')
                                 .with(project: project, additional_properties: { value: scan_count, label: anything,
                                                                                  property: policy_source,
                                                                                  time_window: time_window })
    end
  end

  describe '#perform' do
    before do
      allow_next_found_instance_of(Security::OrchestrationPolicyConfiguration) do |instance|
        allow(instance).to receive(:active_scan_execution_policies).and_return([policy])
      end
    end

    subject(:run_worker) { described_class.new.perform(project_id, current_user_id, schedule_id, branch) }

    context 'when project is not found' do
      let(:project_id) { non_existing_record_id }

      it_behaves_like 'does not call CreatePipelineService'
    end

    context 'when user is not found' do
      let(:current_user_id) { non_existing_record_id }

      it_behaves_like 'does not call CreatePipelineService'
    end

    context 'when the user and project exists' do
      it 'delegates the pipeline creation to Security::SecurityOrchestrationPolicies::CreatePipelineService' do
        expect(::Security::SecurityOrchestrationPolicies::CreatePipelineService).to(
          receive(:new)
            .with(project: project, current_user: current_user, params: params)
            .and_call_original)

        run_worker
      end

      it_behaves_like 'tracks scheduled_scan_execution metrics', 1, 'project', 0

      context 'when the schedule defines the time_window' do
        before do
          allow_next_found_instance_of(Security::OrchestrationPolicyRuleSchedule) do |instance|
            allow(instance).to receive(:time_window).and_return(3600)
          end
        end

        it_behaves_like 'tracks scheduled_scan_execution metrics', 1, 'project', 1
      end

      describe 'action limit' do
        let(:action_limit) { 2 }
        let(:actions) { [{ scan: 'sast' }, { scan: 'dast' }, { scan: 'secret_detection' }] }
        let(:policy) { build(:scan_execution_policy, enabled: true, actions: actions) }
        let(:expected_params) { { actions: actions.first(action_limit), branch: branch } }

        before do
          allow(Gitlab::CurrentSettings).to receive(:scan_execution_policies_action_limit).and_return(action_limit)
        end

        it 'limits the number of actions' do
          expect(::Security::SecurityOrchestrationPolicies::CreatePipelineService).to(
            receive(:new)
              .with(project: project, current_user: current_user, params: expected_params)
              .and_call_original)

          run_worker
        end

        context 'when value is zero' do
          let(:action_limit) { 0 }
          let(:expected_params) { { actions: actions, branch: branch } }

          it 'does not limit the number of actions' do
            expect(::Security::SecurityOrchestrationPolicies::CreatePipelineService).to(
              receive(:new)
                .with(project: project, current_user: current_user, params: expected_params)
                .and_call_original)

            run_worker
          end
        end
      end

      context 'when create pipeline service returns errors' do
        before do
          allow_next_instance_of(::Security::SecurityOrchestrationPolicies::CreatePipelineService) do |service|
            allow(service).to receive(:execute).and_return(ServiceResponse.error(message: 'message'))
          end
        end

        it_behaves_like 'tracks scheduled_scan_execution metrics', 1, 'project', 0

        it 'logs the error' do
          expect(::Gitlab::AppJsonLogger).to receive(:warn).with({
            'class' => 'Security::ScanExecutionPolicies::CreatePipelineWorker',
            'security_orchestration_policy_configuration_id' => security_orchestration_policy_configuration.id,
            'user_id' => current_user.id,
            'message' => 'message'
          })
          run_worker
        end

        context 'when the schedule defines the time_window' do
          before do
            allow_next_found_instance_of(Security::OrchestrationPolicyRuleSchedule) do |instance|
              allow(instance).to receive(:time_window).and_return(3600)
            end
          end

          it_behaves_like 'tracks scheduled_scan_execution metrics', 1, 'project', 1

          context 'with multiple scans' do
            let(:policy) do
              build(:scan_execution_policy, enabled: true, actions: [{ scan: 'sast' }, { scan: 'secret_detection' }])
            end

            it_behaves_like 'tracks scheduled_scan_execution metrics', 2, 'project', 1
          end
        end
      end
    end
  end
end
