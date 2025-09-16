# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Standards::Gitlab::DastService,
  feature_category: :compliance_management do
  let_it_be_with_reload(:project) { create(:project, :in_group) }
  let(:params) { {} }

  let(:service) { described_class.new(project: project, params: params) }

  before do
    allow(project).to receive(:default_branch).and_return('master')
  end

  describe '#execute' do
    context 'when group_level_compliance_dashboard feature is not available' do
      let(:master_pipeline_success) { create(:ci_pipeline, :success, project: project, ref: "master") }
      let(:ci_build_master_success) { create(:ci_build, pipeline: master_pipeline_success, project: project) }

      before do
        stub_licensed_features(group_level_compliance_dashboard: false)
        create(:ee_ci_job_artifact, :dast, project: project, job: ci_build_master_success)
      end

      it 'returns feature not available error' do
        response = service.execute

        expect(response.status).to eq(:error)
        expect(response.message).to eq('Compliance standards adherence feature not available')
      end
    end

    context 'when group_level_compliance_dashboard feature is available' do
      before do
        stub_licensed_features(group_level_compliance_dashboard: true)
      end

      shared_examples 'scanner run marked fail' do
        it 'sets scanner run check as fail' do
          response = service.execute

          expect(response.status).to eq(:success)
          expect(project.compliance_standards_adherence.last)
            .to have_attributes(
              project_id: project.id,
              namespace_id: project.namespace_id,
              status: 'fail',
              check_name: 'dast',
              standard: 'gitlab'
            )
        end
      end

      context 'when project has successful pipeline for default branch' do
        let(:master_pipeline_success) { create(:ci_pipeline, :success, project: project, ref: "master") }
        let(:ci_build_master_success) { create(:ci_build, pipeline: master_pipeline_success, project: project) }

        context 'when the pipeline has dast job artifacts' do
          before do
            create(:ee_ci_job_artifact, :dast, project: project, job: ci_build_master_success)
          end

          it 'sets scanner run as success' do
            response = service.execute

            expect(response.status).to eq(:success)
            expect(project.compliance_standards_adherence.last)
              .to have_attributes(
                project_id: project.id,
                namespace_id: project.namespace_id,
                status: 'success',
                check_name: 'dast',
                standard: 'gitlab'
              )
          end

          context 'when adherence check for scan already exists' do
            let_it_be(:adherence) do
              create(:compliance_standards_adherence, project: project, check_name: :dast, standard: :gitlab)
            end

            it 'updates the timestamp of the existing adherence check' do
              initial_updated_at = adherence.updated_at

              travel_to(2.days.from_now) do
                response = service.execute

                expect(response.status).to eq(:success)

                expect((adherence.reload.updated_at.to_date - initial_updated_at.to_date).to_i).to eq(2)
              end
            end
          end
        end

        context 'when the pipeline do not have dast job artifacts' do
          it_behaves_like 'scanner run marked fail'
        end
      end

      context 'when project does not have successful pipeline for default branch' do
        let(:master_pipeline_failed) { create(:ci_pipeline, :failed, project: project, ref: "master") }
        let(:ci_build_master_failed) { create(:ci_build, pipeline: master_pipeline_failed, project: project) }

        before do
          create(:ee_ci_job_artifact, :dast, project: project, job: ci_build_master_failed)
        end

        it_behaves_like 'scanner run marked fail'
      end

      context 'when project has successful pipeline for non default branch with dast artifacts' do
        let(:nonmaster_pipeline_success) { create(:ci_pipeline, :failed, project: project, ref: "nonmaster") }
        let(:ci_build_nonmaster_success) { create(:ci_build, pipeline: nonmaster_pipeline_success, project: project) }

        before do
          create(:ee_ci_job_artifact, :dast, project: project, job: ci_build_nonmaster_success)
        end

        it_behaves_like 'scanner run marked fail'
      end
    end
  end
end
