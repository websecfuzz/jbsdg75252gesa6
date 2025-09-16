# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::JobsInjector, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user, developer_of: project) }

  let(:pipeline) do
    build(:ci_pipeline, project: project, ref: 'master', user: user).tap do |pipeline|
      pipeline.stages = [build(:ci_stage, name: 'test', position: 1, pipeline: pipeline).tap do |stage|
        stage.statuses = [build(:ci_build, name: 'test-job', stage_idx: 1)]
      end]
    end
  end

  let(:pipeline_stage) { pipeline.stages.first }
  let(:stage_to_inject) { build(:ci_stage, name: 'build', position: 3, pipeline: build(:ci_empty_pipeline)) }
  let(:job_to_inject) do
    build(:ci_build, name: 'build-job', stage_idx: 3, stage: stage_to_inject)
  end

  let(:declared_stages) { %w[build test deploy] }
  let(:jobs_to_inject) { [job_to_inject] }
  let(:on_conflict) { nil }
  let(:service) { described_class.new(pipeline: pipeline, declared_stages: declared_stages, on_conflict: on_conflict) }
  let(:injected_job) { pipeline_stage.statuses.find { |status| status.name == job_to_inject.name } }

  describe '#inject_jobs' do
    subject(:inject) { service.inject_jobs(jobs: jobs_to_inject, stage: stage_to_inject) }

    describe 'stage injection' do
      let(:injected_stage) { pipeline.stages.find { |stage| stage.name == stage_to_inject.name } }

      it 'adds the stage to the target pipeline' do
        expect { inject }.to change { pipeline.stages.size }.by(1)

        expect(pipeline.stages.map(&:name)).to contain_exactly('build', 'test')
      end

      it 'assigns correct stage attributes based on the target pipeline' do
        inject

        expect(injected_stage).to have_attributes(pipeline: pipeline, position: 0)
      end

      context 'when stage already exists in the pipeline' do
        let(:other_pipeline) { build(:ci_empty_pipeline) }
        let(:stage_to_inject) { build(:ci_stage, name: 'test', position: 2, pipeline: other_pipeline) }

        it 'does not change the existing pipeline stages' do
          expect { inject }.not_to change { pipeline.stages.size }.from(1)

          existing_stage = pipeline.stages.first
          expect(existing_stage).to have_attributes(pipeline: pipeline, position: 1)
        end
      end

      context 'when stage does not exist in declared_stages' do
        let(:declared_stages) { %w[test] }

        it 'does not change the pipeline stages' do
          expect { inject }.not_to change { pipeline.stages.size }
        end

        context 'with multiple jobs' do
          let(:job_to_inject_2) do
            build(:ci_build, name: 'build-job-2', stage_idx: 3, stage: stage_to_inject)
          end

          let(:jobs_to_inject) { [job_to_inject, job_to_inject_2] }

          it 'does not change the pipeline stages' do
            expect { inject }.not_to change { pipeline.stages.size }
            expect(pipeline.stages.map(&:name)).to contain_exactly('test')
            expect(pipeline_stage.statuses.map(&:name)).to contain_exactly 'test-job'
          end
        end
      end
    end

    describe 'job injection' do
      let(:stage_to_inject) { build(:ci_stage, name: pipeline_stage.name, position: 3) }

      it 'adds the job to the target stage' do
        expect { inject }.to change { pipeline_stage.statuses.size }.by(1)

        expect(pipeline_stage.statuses.map(&:name)).to contain_exactly('build-job', 'test-job')
      end

      it 'assigns correct attributes based on the target stage' do
        inject

        expect(injected_job).to have_attributes(pipeline: pipeline, stage_idx: 1)
      end

      context 'with on_conflict' do
        let(:on_conflict) { ->(job_name) { "#{job_name}:suffix" } }

        context 'without conflicts' do
          it 'injects the job with the same name' do
            inject

            expect(injected_job.name).to eq 'build-job'
          end

          context 'when job has needs' do
            before do
              job_to_inject.needs << build(:ci_build_need, name: 'test-job')
            end

            it 'does not update the needs with the suffix' do
              inject

              expect(injected_job.needs.first.name).to eq 'test-job'
            end
          end
        end

        context 'with conflicts' do
          let(:job_to_inject) do
            build(:ci_build, name: 'test-job', stage_idx: 3)
          end

          it 'adds suffix to the injected job' do
            inject

            expect(injected_job.name).to eq 'test-job:suffix'
          end

          context 'when jobs have needs' do
            let(:jobs_to_inject) { [job_to_inject, job_with_needs_to_inject] }
            let(:job_with_needs_to_inject) do
              build(:ci_build, name: 'other-job', stage_idx: 4).tap do |job|
                job.needs << build(:ci_build_need, name: 'test-job')
              end
            end

            it 'updates the needs with the suffix' do
              inject

              injected_job_with_needs = pipeline_stage.statuses
                                                      .find { |status| status.name == job_with_needs_to_inject.name }
              expect(injected_job_with_needs.needs.first.name).to eq 'test-job:suffix'
            end
          end

          context 'when job has unrelated needs that were not renamed' do
            it 'does not add the suffix' do
              job_to_inject.needs << build(:ci_build_need, name: 'other-job')
              inject

              expect(injected_job.needs.first.name).to eq 'other-job'
            end
          end

          context 'when on_conflict lambda returns nil' do
            let(:on_conflict) { ->(_job_name) { nil } }

            it 'injects the job with the same name' do
              expect { inject }.to raise_error(
                ::Gitlab::Ci::Pipeline::JobsInjector::DuplicateJobNameError, 'job names must be unique (test-job)'
              )
            end
          end
        end
      end
    end
  end
end
