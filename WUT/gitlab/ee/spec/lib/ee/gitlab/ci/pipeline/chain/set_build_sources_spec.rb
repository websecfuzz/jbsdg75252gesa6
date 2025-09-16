# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::Chain::SetBuildSources, feature_category: :security_policy_management do
  include RepoHelpers

  let(:opts) { {} }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :repository, group: group) }
  let_it_be(:user) { create(:user, developer_of: [project]) }

  let(:command) do
    Gitlab::Ci::Pipeline::Chain::Command.new(
      project: project,
      current_user: user,
      origin_ref: 'master'
    )
  end

  let(:pipeline) { build(:ci_pipeline, project: project) }

  subject(:perform) do
    described_class.new(pipeline, command).perform!
  end

  describe '#perform!' do
    let(:pipeline_seed) do
      pipeline_seed = instance_double(Gitlab::Ci::Pipeline::Seed::Pipeline)
      allow(pipeline_seed).to receive(:stages).and_return(
        [
          instance_double(Ci::Stage, statuses: [
            build_double(name: "build", options: {}),
            build_double(name: "namespace_policy_job", options: { execution_policy_job: true })
          ]),
          instance_double(Ci::Stage, statuses: [
            build_double(name: "rspec", options: {}),
            build_double(name: "secret-detection-0", options: {}),
            build_double(name: "project_policy_job", options: { execution_policy_job: true }),
            build_double(name: "secret-detection-1", options: { execution_policy_job: true }),
            build_double(name: "arbitrary-job-name", options: {})
          ])
        ]
      )
      pipeline_seed
    end

    before do
      allow(command).to receive(:pipeline_seed).and_return(pipeline_seed)
    end

    context 'with security policy' do
      let(:scan_execution_context) do
        instance_double(::Gitlab::Ci::Pipeline::ScanExecutionPolicies::PipelineContext)
      end

      it 'sets correct build and pipeline source for jobs' do
        expected_sources = {
          "build" => pipeline.source,
          "namespace_policy_job" => "pipeline_execution_policy",
          "rspec" => pipeline.source,
          "secret-detection-0" => "scan_execution_policy",
          "project_policy_job" => "pipeline_execution_policy",
          "secret-detection-1" => "pipeline_execution_policy",
          "arbitrary-job-name" => "scan_execution_policy"
        }

        expect(command.pipeline_policy_context).to receive(:scan_execution_context)
          .with(pipeline.source_ref_path)
          .at_least(:once)
          .and_return(scan_execution_context)

        pipeline_seed.stages.flat_map(&:statuses).each do |build|
          allow(scan_execution_context).to receive(:job_injected?)
            .with(build)
            .and_return(expected_sources[build.name] == "scan_execution_policy")

          expect(build).to receive(:build_build_source).with(
            source: expected_sources[build.name],
            project_id: project.id
          )
        end

        perform
      end
    end
  end

  private

  def build_double(**args)
    double = instance_double(::Ci::Build, args[:name], **args)
    allow(double).to receive(:instance_of?).with(::Ci::Build).and_return(true)
    double
  end
end
