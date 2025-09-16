# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::CreatePipelineService, feature_category: :security_policy_management do # rubocop:disable RSpec/SpecFilePathFormat -- path is correct
  include RepoHelpers

  let(:opts) { {} }
  let_it_be(:group) { create(:group) }
  let_it_be_with_refind(:project) { create(:project, :repository, :auto_devops_disabled, group: group) }
  let_it_be_with_reload(:compliance_project) { create(:project, :empty_repo, group: group) }
  let_it_be(:user) { create(:user, developer_of: [project, compliance_project]) }

  let(:namespace_policy_content) { { namespace_policy_job: { stage: 'build', script: 'namespace script' } } }
  let(:namespace_policy_file) { 'namespace-policy.yml' }
  let(:namespace_policy) do
    build(:pipeline_execution_policy,
      content: { include: [{
        project: compliance_project.full_path,
        file: namespace_policy_file,
        ref: compliance_project.default_branch_or_main
      }] })
  end

  let(:namespace_policy_yaml) do
    build(:orchestration_policy_yaml, pipeline_execution_policy: [namespace_policy])
  end

  let_it_be_with_reload(:namespace_policies_project) { create(:project, :empty_repo, group: group) }

  let_it_be(:namespace_configuration) do
    create(:security_orchestration_policy_configuration,
      project: nil, namespace: group, security_policy_management_project: namespace_policies_project)
  end

  let(:project_policy_content) { { project_policy_job: { script: 'project script' } } }
  let(:project_policy_file) { 'project-policy.yml' }
  let(:project_policy) do
    build(:pipeline_execution_policy,
      content: { include: [{
        project: compliance_project.full_path,
        file: project_policy_file,
        ref: compliance_project.default_branch_or_main
      }] })
  end

  let(:project_policy_yaml) do
    build(:orchestration_policy_yaml, pipeline_execution_policy: [project_policy])
  end

  let_it_be_with_reload(:project_policies_project) { create(:project, :empty_repo, group: group) }

  let_it_be(:project_configuration) do
    create(:security_orchestration_policy_configuration,
      project: project, security_policy_management_project: project_policies_project)
  end

  let(:project_ci_yaml) do
    <<~YAML
      build:
        stage: build
        script:
          - echo 'build'
      rspec:
        stage: test
        script:
          -echo 'test'
    YAML
  end

  let(:service) { described_class.new(project, user, { ref: 'master' }) }

  around do |example|
    create_and_delete_files(project, { '.gitlab-ci.yml' => project_ci_yaml }) do
      create_and_delete_files(
        project_policies_project, { '.gitlab/security-policies/policy.yml' => project_policy_yaml }
      ) do
        create_and_delete_files(
          namespace_policies_project, { '.gitlab/security-policies/policy.yml' => namespace_policy_yaml }
        ) do
          create_and_delete_files(
            compliance_project, {
              project_policy_file => project_policy_content.to_yaml,
              namespace_policy_file => namespace_policy_content.to_yaml
            }
          ) do
            example.run
          end
        end
      end
    end
  end

  before do
    stub_licensed_features(security_orchestration_policies: true)
  end

  describe '#execute' do
    subject(:execute) do
      service.execute(:push, **opts)
    end

    context 'with security policy' do
      let(:scan_execution_policy) do
        build(:scan_execution_policy, actions: [
          { scan: 'secret_detection' },
          { scan: 'sast_iac' },
          { scan: 'container_scanning' },
          { scan: 'sast' },
          { scan: 'dast', site_profile: '', scanner_profile: '' }
        ])
      end

      let(:project_policy_yaml) do
        build(:orchestration_policy_yaml,
          pipeline_execution_policy: [project_policy],
          scan_execution_policy: [scan_execution_policy])
      end

      before do
        create(:security_policy, :scan_execution_policy, linked_projects: [project],
          content: scan_execution_policy.slice(:actions),
          security_orchestration_policy_configuration: project_configuration)
      end

      it 'sets correct build and pipeline source for jobs' do
        expected_sources = {
          "build" => nil,
          "namespace_policy_job" => "pipeline_execution_policy",
          "rspec" => nil,
          "dast-on-demand-0" => "scan_execution_policy",
          "secret-detection-0" => "scan_execution_policy",
          "kics-iac-sast-1" => "scan_execution_policy",
          "container-scanning-2" => "scan_execution_policy",
          "semgrep-sast-3" => "scan_execution_policy",
          "project_policy_job" => "pipeline_execution_policy"
        }

        pipeline = nil
        expect do
          pipeline = execute.payload
        end.to change { Ci::BuildSource.count }.by(9)

        pipeline.builds.each do |build|
          source = Ci::BuildSource.find_by(build_id: build.id, project_id: project.id)
          expect(source.source).to eq(expected_sources[build.name] || pipeline.source)
        end
      end
    end
  end
end
