# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ProjectComplianceEvaluatorWorker, feature_category: :compliance_management do
  let(:worker) { described_class.new }
  let(:evaluator) { instance_double(ComplianceManagement::ComplianceRequirements::ExpressionEvaluator) }
  let(:external_control_service) do
    instance_double(ComplianceManagement::ComplianceFramework::ComplianceRequirements::TriggerExternalControlService)
  end

  let(:status_service) do
    instance_double(ComplianceManagement::ComplianceFramework::ComplianceRequirementsControls::UpdateStatusService)
  end

  let_it_be(:framework) { create(:compliance_framework) }
  let_it_be(:requirement) { create(:compliance_requirement, framework: framework) }
  let_it_be(:control) { create(:compliance_requirements_control, compliance_requirement: requirement) }
  let_it_be(:external_control) do
    create(:compliance_requirements_control, :external, compliance_requirement: requirement)
  end

  let_it_be(:project) { create(:project) }
  let_it_be(:project2) { create(:project) }

  let_it_be(:policy_config) { create(:security_orchestration_policy_configuration) }

  let_it_be(:compliance_framework_security_policy) do
    create(:compliance_framework_security_policy,
      framework: framework,
      policy_configuration: policy_config,
      policy_index: 0)
  end

  let_it_be(:policy_read1) do
    create(:scan_result_policy_read,
      :prevent_approval_by_author,
      :blocking_protected_branches,
      :remove_approvals_with_new_commit,
      :prevent_approval_by_commit_author,
      project: project,
      security_orchestration_policy_configuration: policy_config)
  end

  let_it_be(:policy_read2) do
    create(:scan_result_policy_read,
      :prevent_approval_by_author,
      :blocking_protected_branches,
      :remove_approvals_with_new_commit,
      :prevent_approval_by_commit_author,
      project: project2,
      security_orchestration_policy_configuration: policy_config)
  end

  let(:approval_settings_project1) { [policy_read1.project_approval_settings] }
  let(:approval_settings_project2) { [policy_read2.project_approval_settings] }

  let(:requirement_status_service) do
    instance_double(ComplianceManagement::ComplianceFramework::ComplianceRequirements::RefreshStatusService)
  end

  before do
    framework.projects << [project, project2]
    allow(ComplianceManagement::ComplianceFramework::ComplianceRequirements::RefreshStatusService)
      .to receive(:new).and_return(requirement_status_service)
    allow(requirement_status_service).to receive(:execute)
  end

  describe '#perform' do
    subject(:perform) { worker.perform(framework.id, [project.id, project2.id]) }

    before do
      stub_feature_flags(evaluate_compliance_controls: true)

      allow(ComplianceManagement::ComplianceRequirements::ExpressionEvaluator)
        .to receive(:new)
              .with(control, project, approval_settings_project1)
              .and_return(evaluator)
      allow(ComplianceManagement::ComplianceFramework::ComplianceRequirements::TriggerExternalControlService)
        .to receive(:new)
              .with(project, external_control)
              .and_return(external_control_service)
      allow(ComplianceManagement::ComplianceRequirements::ExpressionEvaluator)
        .to receive(:new)
              .with(control, project2, approval_settings_project2)
              .and_return(evaluator)
      allow(ComplianceManagement::ComplianceFramework::ComplianceRequirements::TriggerExternalControlService)
        .to receive(:new)
              .with(project2, external_control)
              .and_return(external_control_service)
      allow(evaluator).to receive(:evaluate).and_return(true)
      allow(external_control_service).to receive(:execute).and_return(ServiceResponse.success)

      allow(ComplianceManagement::ComplianceFramework::ComplianceRequirementsControls::UpdateStatusService)
        .to receive(:new)
              .and_return(status_service)
      allow(status_service).to receive(:execute)
    end

    shared_examples 'refreshes the requirement status' do
      it 'refreshes the requirement status' do
        expect(requirement_status_service).to receive(:execute).twice

        perform
      end
    end

    it_behaves_like 'an idempotent worker' do
      let(:job_args) { [framework.id, [project.id]] }
    end

    it 'has the `until_executed` deduplicate strategy' do
      expect(described_class.get_deduplicate_strategy).to eq(:until_executed)
    end

    context 'when the feature flag is disabled' do
      before do
        stub_feature_flags(evaluate_compliance_controls: false)
      end

      it 'returns early without processing' do
        expect(ComplianceManagement::Framework).not_to receive(:find_by_id)

        perform
      end
    end

    context 'when framework is not assigned to project anymore' do
      before do
        project2.compliance_management_frameworks.destroy framework
      end

      it 'only evaluates for projects where the framework is assigned' do
        expect(ComplianceManagement::ComplianceRequirements::ExpressionEvaluator)
          .to receive(:new).with(control, project, approval_settings_project1).once

        expect(ComplianceManagement::ComplianceFramework::ComplianceRequirements::TriggerExternalControlService)
          .to receive(:new).with(project, external_control).once

        expect(ComplianceManagement::ComplianceRequirements::ExpressionEvaluator)
          .not_to receive(:new).with(control, project2, approval_settings_project2)

        expect(ComplianceManagement::ComplianceFramework::ComplianceRequirements::TriggerExternalControlService)
          .not_to receive(:new).with(project2, external_control)

        expect(evaluator).to receive(:evaluate).once
        expect(external_control_service).to receive(:execute).once

        perform
      end
    end

    context 'when given valid parameters' do
      it 'evaluates each control for each project' do
        expect(ComplianceManagement::ComplianceRequirements::ExpressionEvaluator)
          .to receive(:new)
                .with(control, project, approval_settings_project1)
                .once

        expect(ComplianceManagement::ComplianceFramework::ComplianceRequirements::TriggerExternalControlService)
          .to receive(:new).with(project, external_control).once

        expect(ComplianceManagement::ComplianceRequirements::ExpressionEvaluator)
          .to receive(:new)
                .with(control, project2, approval_settings_project2)
                .once

        expect(ComplianceManagement::ComplianceFramework::ComplianceRequirements::TriggerExternalControlService)
          .to receive(:new).with(project2, external_control).once

        expect(evaluator).to receive(:evaluate).twice
        expect(external_control_service).to receive(:execute).twice

        perform
      end

      it 'updates the status for each control-project pair', :aggregate_failures do
        expect(ComplianceManagement::ComplianceFramework::ComplianceRequirementsControls::UpdateStatusService)
          .to receive(:new)
                .with(
                  current_user: an_instance_of(Gitlab::Audit::UnauthenticatedAuthor),
                  control: control,
                  project: project,
                  status_value: 'pass'
                )
                .once

        expect(ComplianceManagement::ComplianceFramework::ComplianceRequirementsControls::UpdateStatusService)
          .to receive(:new)
                .with(
                  current_user: an_instance_of(Gitlab::Audit::UnauthenticatedAuthor),
                  control: control,
                  project: project2,
                  status_value: 'pass'
                )
                .once

        expect(status_service).to receive(:execute).twice

        perform
      end

      it_behaves_like 'refreshes the requirement status'
    end

    context 'when control evaluation returns false' do
      before do
        allow(evaluator).to receive(:evaluate).and_return(false)
      end

      it 'updates the status with "fail"', :aggregate_failures do
        expect(ComplianceManagement::ComplianceFramework::ComplianceRequirementsControls::UpdateStatusService)
          .to receive(:new)
                .with(
                  current_user: an_instance_of(Gitlab::Audit::UnauthenticatedAuthor),
                  control: control,
                  project: project,
                  status_value: 'fail'
                )
                .once

        expect(ComplianceManagement::ComplianceFramework::ComplianceRequirementsControls::UpdateStatusService)
          .to receive(:new)
                .with(
                  current_user: an_instance_of(Gitlab::Audit::UnauthenticatedAuthor),
                  control: control,
                  project: project2,
                  status_value: 'fail'
                )
                .once

        perform
      end

      it_behaves_like 'refreshes the requirement status'
    end

    context 'with invalid parameters' do
      it 'returns early when framework is not found' do
        expect(worker.perform(non_existing_record_id, [project.id])).to be_nil
      end
    end

    context 'when errors occur during evaluation' do
      let(:error) { StandardError.new("Test error") }

      before do
        allow(evaluator).to receive(:evaluate).and_raise(error)
        allow(Gitlab::ErrorTracking).to receive(:log_exception)
      end

      it 'logs the exception and continues processing' do
        expect(Gitlab::ErrorTracking).to receive(:log_exception).with(
          error,
          framework_id: control.compliance_requirement.framework_id,
          control_id: control.id,
          project_id: project.id
        ).once

        expect(Gitlab::ErrorTracking).to receive(:log_exception).with(
          error,
          framework_id: control.compliance_requirement.framework_id,
          control_id: control.id,
          project_id: project2.id
        ).once

        expect(ComplianceManagement::ComplianceRequirements::ExpressionEvaluator)
          .to receive(:new).twice

        perform
      end

      it 'does not call the update service when all evaluations fail' do
        expect(status_service).not_to receive(:execute)

        perform
      end

      it_behaves_like 'refreshes the requirement status'
    end

    context 'when errors occur during status update' do
      let(:update_error) { StandardError.new("Update error") }

      before do
        allow(status_service).to receive(:execute).and_raise(update_error)
        allow(Gitlab::ErrorTracking).to receive(:log_exception)
      end

      it 'logs the exception and continues with remaining updates' do
        expect(Gitlab::ErrorTracking).to receive(:log_exception).with(
          update_error,
          hash_including(
            control_id: control.id,
            project_id: project.id,
            status_value: 'pass'
          )
        ).once

        expect(Gitlab::ErrorTracking).to receive(:log_exception).with(
          update_error,
          hash_including(
            control_id: control.id,
            project_id: project2.id,
            status_value: 'pass'
          )
        ).once

        expect(status_service).to receive(:execute).twice

        perform
      end

      it 'attempts to update all statuses even if some fail' do
        expect(ComplianceManagement::ComplianceFramework::ComplianceRequirementsControls::UpdateStatusService)
          .to receive(:new).twice

        perform
      end

      it_behaves_like 'refreshes the requirement status'
    end

    context 'when some evaluations succeed and some fail' do
      let(:evaluation_error) { StandardError.new("Evaluation error") }

      before do
        first_evaluator = instance_double(ComplianceManagement::ComplianceRequirements::ExpressionEvaluator)
        second_evaluator = instance_double(ComplianceManagement::ComplianceRequirements::ExpressionEvaluator)

        allow(ComplianceManagement::ComplianceRequirements::ExpressionEvaluator)
          .to receive(:new)
                .with(control, project, approval_settings_project1)
                .and_return(first_evaluator)
        allow(ComplianceManagement::ComplianceRequirements::ExpressionEvaluator)
          .to receive(:new)
                .with(control, project2, approval_settings_project2)
                .and_return(second_evaluator)

        allow(first_evaluator).to receive(:evaluate).and_return(true)
        allow(second_evaluator).to receive(:evaluate).and_raise(evaluation_error)

        allow(Gitlab::ErrorTracking).to receive(:log_exception)
      end

      it 'logs exception for failed evaluation' do
        expect(Gitlab::ErrorTracking).to receive(:log_exception).with(
          evaluation_error,
          framework_id: control.compliance_requirement.framework_id,
          control_id: control.id,
          project_id: project2.id
        ).once

        perform
      end

      it 'only updates statuses for successful evaluations' do
        expect(ComplianceManagement::ComplianceFramework::ComplianceRequirementsControls::UpdateStatusService)
          .to receive(:new)
                .with(
                  current_user: an_instance_of(Gitlab::Audit::UnauthenticatedAuthor),
                  control: control,
                  project: project,
                  status_value: 'pass'
                )
                .once

        expect(status_service).to receive(:execute).once

        perform
      end

      it_behaves_like 'refreshes the requirement status'
    end
  end

  describe '.schedule_compliance_evaluation' do
    subject(:schedule) { described_class.schedule_compliance_evaluation(framework.id, [project.id, project2.id]) }

    it 'schedules the job with the appropriate delay' do
      expect(described_class).to receive(:perform_in)
        .with(ComplianceManagement::ComplianceFramework::ProjectSettings::PROJECT_EVALUATOR_WORKER_DELAY,
          framework.id, [project.id, project2.id]).and_call_original

      schedule
    end
  end
end
