# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::FrameworkEvaluationSchedulerWorker, feature_category: :compliance_management do
  describe '#perform' do
    let(:worker) { described_class.new }

    it_behaves_like 'an idempotent worker'

    context 'when feature flag is enabled' do
      before do
        stub_feature_flags(evaluate_compliance_controls: true)
      end

      context 'when frameworks exist' do
        let_it_be(:framework_1) { create(:compliance_framework) }
        let_it_be(:framework_2) { create(:compliance_framework) }
        let_it_be(:framework_without_projects) { create(:compliance_framework) }

        let_it_be(:projects) { create_list(:project, 7) }

        before do
          [framework_1, framework_2, framework_without_projects].each do |framework|
            create(:compliance_requirement, framework: framework).tap do |req|
              create(:compliance_requirements_control, compliance_requirement: req)
            end
          end

          projects[0..3].each do |project|
            create(:compliance_framework_project_setting,
              project: project,
              compliance_management_framework: framework_1)
          end

          projects[4..6].each do |project|
            create(:compliance_framework_project_setting,
              project: project,
              compliance_management_framework: framework_2)
          end

          stub_const("#{described_class}::PROJECT_BATCH_SIZE", 2)
          stub_const("#{described_class}::FRAMEWORK_BATCH_SIZE", 1)
        end

        it 'processes frameworks and projects in batches' do
          expect(ComplianceManagement::ProjectComplianceEvaluatorWorker)
            .to receive(:perform_async) do |framework_id, project_ids|
            expect(framework_id).to eq(framework_1.id)
            expect(project_ids.size).to eq(2)
          end.ordered.once

          expect(ComplianceManagement::ProjectComplianceEvaluatorWorker)
            .to receive(:perform_async) do |framework_id, project_ids|
            expect(framework_id).to eq(framework_1.id)
            expect(project_ids.size).to eq(2)
          end.ordered.once

          expect(ComplianceManagement::ProjectComplianceEvaluatorWorker)
            .to receive(:perform_async) do |framework_id, project_ids|
            expect(framework_id).to eq(framework_2.id)
            expect(project_ids.size).to eq(2)
          end.ordered.once

          expect(ComplianceManagement::ProjectComplianceEvaluatorWorker)
            .to receive(:perform_async) do |framework_id, project_ids|
            expect(framework_id).to eq(framework_2.id)
            expect(project_ids.size).to eq(1)
          end.ordered.once

          expect(ComplianceManagement::ProjectComplianceEvaluatorWorker)
            .not_to receive(:perform_async)
                      .with(framework_without_projects.id, anything)

          worker.perform
        end
      end

      context 'when no frameworks exist' do
        before do
          allow(ComplianceManagement::Framework)
            .to receive(:with_active_controls)
                  .and_return(ComplianceManagement::Framework.none)
        end

        it 'does not schedule any jobs' do
          expect(ComplianceManagement::ProjectComplianceEvaluatorWorker)
            .not_to receive(:perform_async)

          worker.perform
        end
      end
    end

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(evaluate_compliance_controls: false)
      end

      it 'does not schedule any jobs' do
        expect(ComplianceManagement::ProjectComplianceEvaluatorWorker)
          .not_to receive(:perform_async)

        worker.perform
      end
    end
  end
end
