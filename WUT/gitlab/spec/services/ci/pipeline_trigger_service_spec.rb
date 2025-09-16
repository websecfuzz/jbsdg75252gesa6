# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::PipelineTriggerService, feature_category: :continuous_integration do
  include AfterNextHelpers

  let_it_be(:project) { create(:project, :repository) }

  before do
    stub_ci_pipeline_to_return_yaml_file
    project.update!(ci_pipeline_variables_minimum_override_role: :developer)
  end

  describe '#execute' do
    let_it_be(:user) { create(:user) }

    let(:result) { described_class.new(project, user, params).execute }

    before do
      project.add_developer(user)
    end

    shared_examples 'detecting an unprocessable pipeline trigger' do
      context 'when the pipeline was not created successfully' do
        let(:fail_pipeline) do
          receive(:execute).and_wrap_original do |original, *args, **kwargs|
            response = original.call(*args, **kwargs)
            pipeline = response.payload
            pipeline.update!(failure_reason: 'unknown_failure')

            response
          end
        end

        before do
          allow_next(Ci::CreatePipelineService).to fail_pipeline
        end

        it 'has the correct status code' do
          expect { result }.to change { Ci::Pipeline.count }
          expect(result).to be_error
          expect(result.http_status).to eq(:unprocessable_entity)
        end
      end
    end

    shared_examples 'accepting inputs' do
      let(:inputs) do
        {
          deploy_strategy: 'blue-green',
          job_stage: 'deploy',
          test_script: ['echo "test"'],
          test_rules: [
            { if: '$CI_PIPELINE_SOURCE == "web"' }
          ]
        }
      end

      before do
        stub_ci_pipeline_yaml_file(
          File.read(Rails.root.join('spec/lib/gitlab/ci/config/yaml/fixtures/complex-included-ci.yml'))
        )
      end

      it 'triggers a pipeline using inputs' do
        expect { result }.to change { Ci::Pipeline.count }.by(1)

        expect(result.payload[:pipeline].builds.map(&:name)).to contain_exactly(
          'my-job-build 1/2', 'my-job-build 2/2', 'my-job-test', 'my-job-deploy'
        )
      end
    end

    context 'with a trigger token' do
      let(:trigger) { create(:ci_trigger, project: project, owner: user) }

      context 'when trigger belongs to a different project' do
        let(:params) { { token: trigger.token, ref: 'master', variables: nil } }
        let(:trigger) { create(:ci_trigger, project: create(:project), owner: user) }

        it 'does nothing' do
          expect { result }.not_to change { Ci::Pipeline.count }
        end
      end

      context 'when trigger owner does not have a permission to read a project' do
        let(:params) { { token: trigger.token, ref: 'master', variables: nil } }
        let(:trigger) { create(:ci_trigger, project: project, owner: create(:user)) }

        it 'does nothing' do
          expect { result }.not_to change { Ci::Pipeline.count }
        end
      end

      context 'when params have an existing trigger token' do
        context 'when params have an existing ref' do
          let(:params) { { token: trigger.token, ref: 'master', variables: nil } }

          it 'triggers a pipeline' do
            expect { result }.to change { Ci::Pipeline.count }.by(1)
            expect(result[:pipeline].ref).to eq('master')
            expect(result[:pipeline].project).to eq(project)
            expect(result[:pipeline].user).to eq(trigger.owner)
            expect(result[:pipeline].trigger).to eq(trigger)
            expect(result[:status]).to eq(:success)
          end

          it 'stores the payload as a variable' do
            expect { result }.to change { Ci::PipelineVariable.count }.by(1)

            var = result[:pipeline].variables.first

            expect(var.key).to eq('TRIGGER_PAYLOAD')
            expect(var.value).to eq('{"ref":"master","variables":null}')
            expect(var.variable_type).to eq('file')
            expect(var.raw).to eq(true)
          end

          context 'when commit message has [ci skip]' do
            before do
              allow_next(Ci::Pipeline).to receive(:git_commit_message) { '[ci skip]' }
            end

            it 'ignores [ci skip] and create as general' do
              expect { result }.to change { Ci::Pipeline.count }.by(1)
              expect(result).to be_success
            end
          end

          context 'when params have a variable' do
            let(:params) { { token: trigger.token, ref: 'master', variables: variables } }
            let(:variables) { { 'AAA' => 'AAA123' } }

            it 'has variables' do
              expect { result }.to change { Ci::PipelineVariable.count }.by(2)
              expect(result[:pipeline].variables.map { |v| { v.key => v.value } }.first).to eq(variables)
            end
          end

          context 'when params have duplicate variables' do
            let(:params) { { token: trigger.token, ref: 'master', variables: variables } }
            let(:variables) { { 'TRIGGER_PAYLOAD' => 'duplicate value' } }

            it 'creates a failed pipeline without variables' do
              expect { result }.to change { Ci::Pipeline.count }
              expect(result).to be_error
              expect(result.message[:base]).to eq(['Duplicate variable name: TRIGGER_PAYLOAD'])
            end
          end

          it_behaves_like 'detecting an unprocessable pipeline trigger'
        end

        context 'when params have a non-existant ref' do
          let(:params) { { token: trigger.token, ref: 'invalid-ref', variables: nil } }

          it 'does not trigger a pipeline' do
            expect { result }.not_to change { Ci::Pipeline.count }
            expect(result).to be_error
            expect(result.http_status).to eq(:bad_request)
          end
        end
      end

      context 'when params have a non-existant trigger token' do
        let(:params) { { token: 'invalid-token', ref: nil, variables: nil } }

        it 'does not trigger a pipeline' do
          expect { result }.not_to change { Ci::Pipeline.count }
          expect(result).to be_nil
        end
      end

      context 'when using inputs' do
        let(:params) { { token: trigger.token, ref: 'master', inputs: inputs } }

        it_behaves_like 'accepting inputs'
      end
    end

    context 'with a pipeline job token' do
      let!(:pipeline) { create(:ci_empty_pipeline, project: project) }
      let(:job) { create(:ci_build, :running, pipeline: pipeline, user: user) }

      context 'when job user does not have a permission to read a project' do
        let(:params) { { token: job.token, ref: 'master', variables: nil } }
        let(:job) { create(:ci_build, pipeline: pipeline, user: create(:user)) }

        it 'does nothing' do
          expect { result }.not_to change { Ci::Pipeline.count }
        end
      end

      context 'when job is not running' do
        let(:params) { { token: job.token, ref: 'master', variables: nil } }
        let(:job) { create(:ci_build, :success, pipeline: pipeline, user: user) }

        it 'does nothing', :aggregate_failures do
          expect { result }.not_to change { Ci::Pipeline.count }
          expect(result[:message]).to eq('Job is not running')
          expect(result[:http_status]).to eq(401)
        end
      end

      context 'when params have a valid job token' do
        context 'when params have an existing ref' do
          let(:params) { { token: job.token, ref: 'master', variables: nil } }

          it 'triggers a pipeline' do
            expect { result }.to change { Ci::Pipeline.count }.by(1)
            expect(result[:pipeline].ref).to eq('master')
            expect(result[:pipeline].project).to eq(project)
            expect(result[:pipeline].user).to eq(job.user)
            expect(result[:status]).to eq(:success)
          end

          it_behaves_like 'logs downstream pipeline creation' do
            let(:downstream_pipeline) { result[:pipeline] }
            let(:expected_root_pipeline) { pipeline }
            let(:expected_hierarchy_size) { 2 }
            let(:expected_downstream_relationship) { :multi_project }
          end

          context 'when commit message has [ci skip]' do
            before do
              allow_next_instance_of(Ci::Pipeline) do |instance|
                allow(instance).to receive(:git_commit_message) { '[ci skip]' }
              end
            end

            it 'ignores [ci skip] and create as general' do
              expect { result }.to change { Ci::Pipeline.count }.by(1)
              expect(result[:status]).to eq(:success)
            end
          end

          context 'when params have a variable' do
            let(:params) { { token: job.token, ref: 'master', variables: variables } }
            let(:variables) { { 'AAA' => 'AAA123' } }

            it 'has variables' do
              expect { result }.to change { Ci::PipelineVariable.count }.by(2)
                               .and change { Ci::Sources::Pipeline.count }.by(1)
              expect(result[:pipeline].variables.map { |v| { v.key => v.value } }.first).to eq(variables)
              expect(job.sourced_pipelines.last.pipeline_id).to eq(result[:pipeline].id)
            end
          end

          context 'when params have duplicate variables' do
            let(:params) { { token: job.token, ref: 'master', variables: variables } }
            let(:variables) { { 'TRIGGER_PAYLOAD' => 'duplicate value' } }

            it 'creates a failed pipeline without variables' do
              expect { result }.to change { Ci::Pipeline.count }
              expect(result).to be_error
              expect(result.message[:base]).to eq(['Duplicate variable name: TRIGGER_PAYLOAD'])
            end
          end

          it_behaves_like 'detecting an unprocessable pipeline trigger'
        end

        context 'when params have a non-existant ref' do
          let(:params) { { token: job.token, ref: 'invalid-ref', variables: nil } }

          it 'does not trigger a job in the pipeline' do
            expect { result }.not_to change { Ci::Pipeline.count }
            expect(result).to be_error
            expect(result.http_status).to eq(:bad_request)
          end
        end
      end

      context 'when params have a non-existsed trigger token' do
        let(:params) { { token: 'invalid-token', ref: nil, variables: nil } }

        it 'does not trigger a pipeline' do
          expect { result }.not_to change { Ci::Pipeline.count }
          expect(result).to be_nil
        end
      end

      context 'when using inputs' do
        let(:params) { { token: job.token, ref: 'master', inputs: inputs } }

        it_behaves_like 'accepting inputs'
      end
    end
  end
end
