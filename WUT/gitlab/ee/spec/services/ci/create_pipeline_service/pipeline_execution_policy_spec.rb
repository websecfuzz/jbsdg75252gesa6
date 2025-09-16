# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::CreatePipelineService, feature_category: :security_policy_management do
  include RepoHelpers

  subject(:execute) { service.execute(source, **opts) }

  let(:source) { :push }
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
          - echo 'test'
    YAML
  end

  let(:service) { described_class.new(project, user, params) }
  let(:params) { { ref: 'master' } }

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
    project.update!(ci_pipeline_variables_minimum_override_role: :developer)
    stub_licensed_features(security_orchestration_policies: true)
  end

  it 'responds with success' do
    expect(execute).to be_success
  end

  it 'persists pipeline' do
    expect(execute.payload).to be_persisted
  end

  it 'persists jobs in the correct stages', :aggregate_failures do
    expect { execute }.to change { Ci::Build.count }.from(0).to(4)

    stages = execute.payload.stages
    expect(stages.map(&:name)).to contain_exactly('build', 'test')

    expect(stages.find_by(name: 'build').builds.map(&:name)).to contain_exactly('build', 'namespace_policy_job')
    expect(stages.find_by(name: 'test').builds.map(&:name)).to contain_exactly('rspec', 'project_policy_job')
  end

  it 'sets the same partition_id for all jobs' do
    # Stub value for current partition to return one value for the first call (project pipeline)
    # and a different value for subsequent calls (policy pipelines)
    allow(::Ci::Pipeline).to receive(:current_partition_value)
                               .and_return(ci_testing_partition_id)

    builds = execute.payload.builds
    expect(builds.map(&:partition_id)).to all(eq(ci_testing_partition_id))
  end

  context 'when policy pipeline stage is not defined in the main pipeline' do
    let(:project_ci_yaml) do
      <<~YAML
        stages:
          - build
        build:
          stage: build
          script:
            - echo 'build'
      YAML
    end

    it 'responds with success' do
      expect(execute).to be_success
    end

    it 'persists the pipeline' do
      expect(execute.payload).to be_persisted
    end

    it 'ignores the policy stage', :aggregate_failures do
      expect { execute }.to change { Ci::Build.count }.from(0).to(2)

      stages = execute.payload.stages
      expect(stages.map(&:name)).to contain_exactly('build')
      expect(stages.find_by(name: 'build').builds.map(&:name)).to contain_exactly('build', 'namespace_policy_job')
    end
  end

  context 'when policy pipelines use declared, but unused project stages' do
    let(:project_ci_yaml) do
      <<~YAML
        stages:
        - build
        - test
        rspec:
          stage: test
          script:
            - echo 'rspec'
      YAML
    end

    it 'responds with success' do
      expect(execute).to be_success
    end

    it 'persists pipeline' do
      expect(execute.payload).to be_persisted
    end

    it 'persists jobs in the correct stages', :aggregate_failures do
      expect { execute }.to change { Ci::Build.count }.from(0).to(3)

      stages = execute.payload.stages
      expect(stages.map(&:name)).to contain_exactly('build', 'test')

      expect(stages.find_by(name: 'build').builds.map(&:name)).to contain_exactly('namespace_policy_job')
      expect(stages.find_by(name: 'test').builds.map(&:name)).to contain_exactly('rspec', 'project_policy_job')
    end
  end

  context 'when policy and project job names are not unique' do
    let(:namespace_policy_content) { { policy_job: { stage: 'build', script: 'namespace script' } } }
    let(:project_ci_yaml) do
      <<~YAML
        policy_job:
          stage: test
          script:
            - echo 'duplicate'
      YAML
    end

    shared_examples_for 'suffixed job added into pipeline' do
      it 'keeps both project job and the policy job, adding suffix for the conflicting job name', :aggregate_failures do
        expect(execute).to be_success
        expect(execute.payload).to be_persisted

        stages = execute.payload.stages
        expect(stages.find_by(name: 'build').builds.map(&:name))
          .to contain_exactly("policy_job:policy-#{namespace_policies_project.id}-0")
        expect(stages.find_by(name: 'test').builds.map(&:name))
          .to contain_exactly('policy_job', 'project_policy_job')
      end
    end

    context 'when policy uses "suffix: on_conflict"' do
      it_behaves_like 'suffixed job added into pipeline'

      context 'when policy has suffix option set explicitly to `on_conflict`' do
        let(:namespace_policy) do
          build(:pipeline_execution_policy, :suffix_on_conflict,
            content: { include: [{
              project: compliance_project.full_path,
              file: namespace_policy_file,
              ref: compliance_project.default_branch_or_main
            }] })
        end

        it_behaves_like 'suffixed job added into pipeline'
      end

      context 'when multiple policies in one policy project use the same job name' do
        let(:other_namespace_policy) do
          build(:pipeline_execution_policy,
            content: { include: [{
              project: compliance_project.full_path,
              file: namespace_policy_file,
              ref: compliance_project.default_branch_or_main
            }] })
        end

        let(:namespace_policy_yaml) do
          build(:orchestration_policy_yaml, pipeline_execution_policy: [namespace_policy, other_namespace_policy])
        end

        it 'keeps all jobs, adding suffix for the conflicting job name', :aggregate_failures do
          expect(execute).to be_success
          expect(execute.payload).to be_persisted

          stages = execute.payload.stages
          expect(stages.find_by(name: 'build').builds.map(&:name))
            .to contain_exactly(
              "policy_job:policy-#{namespace_policies_project.id}-0",
              "policy_job:policy-#{namespace_policies_project.id}-1"
            )
          expect(stages.find_by(name: 'test').builds.map(&:name))
            .to contain_exactly('policy_job', 'project_policy_job')
        end
      end

      context 'when policy job uses "needs"' do
        let(:namespace_policy_content) do
          {
            policy_job: { stage: 'build', script: 'namespace script' },
            namespace_policy_job_with_needs: {
              stage: 'test', script: 'namespace script', needs: ['policy_job']
            }
          }
        end

        let(:project_policy_content) do
          {
            policy_job: { stage: 'build', script: 'project script' },
            project_policy_job_with_needs: { script: 'project script', needs: ['policy_job'] }
          }
        end

        it 'updates needs with suffixes per pipeline for the conflicting jobs', :aggregate_failures do
          expect(execute).to be_success
          expect(execute.payload).to be_persisted

          stages = execute.payload.stages
          test_stage = stages.find_by(name: 'test')
          namespace_policy_job_with_needs = test_stage.builds.find_by(name: 'namespace_policy_job_with_needs')
          expect(namespace_policy_job_with_needs.needs.map(&:name))
            .to contain_exactly("policy_job:policy-#{namespace_policies_project.id}-0")

          project_policy_job_with_needs = test_stage.builds.find_by(name: 'project_policy_job_with_needs')
          expect(project_policy_job_with_needs.needs.map(&:name))
            .to contain_exactly("policy_job:policy-#{project_policies_project.id}-0")

          project_job = test_stage.builds.find_by(name: 'policy_job')
          expect(project_job.needs).to be_empty
        end
      end
    end

    context 'when policy uses "suffix: never"' do
      let(:namespace_policy) do
        build(:pipeline_execution_policy, :suffix_never,
          content: { include: [{
            project: compliance_project.full_path,
            file: namespace_policy_file,
            ref: compliance_project.default_branch_or_main
          }] })
      end

      it 'responds with error', :aggregate_failures do
        expect(execute).to be_error
        expect(execute.payload.errors.full_messages)
          .to contain_exactly(
            "Pipeline execution policy error: job names must be unique (policy_job)"
          )
      end
    end
  end

  context 'with jobs using rules:changes' do
    let(:project_policy_content) do
      {
        project_policy_job: {
          stage: 'test',
          script: 'project script',
          rules: [
            {
              changes: [
                'development.txt'
              ]
            }
          ]
        }
      }
    end

    it 'includes the job' do
      builds = execute.payload.builds

      expect(builds.map(&:name)).to include('project_policy_job')
    end

    context 'when a file is touched in a commit' do
      before_all do
        group.add_owner(user)
      end

      let(:before_sha) { project.repository.commit.sha }
      let(:opts) do
        { origin_ref: project.default_branch_or_main, before_sha: before_sha, source_sha: before_sha,
          target_sha: new_sha }
      end

      let(:new_sha) do
        create_file_in_repo(
          project,
          project.default_branch_or_main,
          project.default_branch_or_main,
          touched_tile_name, 'This is a test',
          commit_message: 'Touch file'
        )[:result]
      end

      context 'when the file listed in changes is not touched' do
        let(:touched_tile_name) { 'production.txt' }

        it 'does not include the job' do
          builds = execute.payload.builds

          expect(builds.map(&:name)).not_to include('project_policy_job')
        end
      end

      context 'when the file listed in changes is touched' do
        let(:touched_tile_name) { 'development.txt' }

        it 'includes the job' do
          builds = execute.payload.builds

          expect(builds.map(&:name)).to include('project_policy_job')
        end
      end
    end
  end

  context 'when any policy contains `override_project_ci` strategy' do
    let(:project_policy) do
      build(:pipeline_execution_policy, :override_project_ci,
        content: { include: [{
          project: compliance_project.full_path,
          file: project_policy_file,
          ref: compliance_project.default_branch_or_main
        }] })
    end

    it 'ignores jobs from project CI', :aggregate_failures do
      expect { execute }.to change { Ci::Build.count }.from(0).to(2)

      stages = execute.payload.stages

      build_stage = stages.find_by(name: 'build')
      expect(build_stage.builds.map(&:name)).to contain_exactly('namespace_policy_job')
      test_stage = stages.find_by(name: 'test')
      expect(test_stage.builds.map(&:name)).to contain_exactly('project_policy_job')
    end

    context 'and override policy uses custom stages' do
      let(:project_policy_content) do
        { stages: %w[build test policy-test deploy],
          project_policy_job: { stage: 'policy-test', script: 'project script' } }
      end

      it 'includes jobs with custom stages' do
        expect { execute }.to change { Ci::Build.count }.from(0).to(2)

        stages = execute.payload.stages

        build_stage = stages.find_by(name: 'build')
        expect(build_stage.builds.map(&:name)).to contain_exactly('namespace_policy_job')
        policy_test_stage = stages.find_by(name: 'policy-test')
        expect(policy_test_stage.builds.map(&:name)).to contain_exactly('project_policy_job')
      end

      context 'and inject_policy policy uses custom stages' do
        let(:namespace_policy_content) do
          { stages: %w[build policy-build],
            namespace_policy_job: { stage: 'policy-build', script: 'policy build script' } }
        end

        let(:namespace_policy) do
          build(:pipeline_execution_policy, :inject_policy,
            content: { include: [{
              project: compliance_project.full_path,
              file: namespace_policy_file,
              ref: compliance_project.default_branch_or_main
            }] })
        end

        it 'includes jobs with custom stages', :aggregate_failures do
          expect { execute }.to change { Ci::Build.count }.from(0).to(2)
          expect(execute).to be_success
          expect(execute.payload).to be_persisted

          stages = execute.payload.stages
          expect(stages.map(&:name)).to contain_exactly('policy-build', 'policy-test')

          expect(stages.find_by(name: 'policy-build').builds.map(&:name)).to contain_exactly('namespace_policy_job')
          expect(stages.find_by(name: 'policy-test').builds.map(&:name)).to contain_exactly('project_policy_job')
        end
      end

      context 'and also namespace policy uses `override_project_ci` with incompatible stages' do
        let(:namespace_policy) do
          build(:pipeline_execution_policy, :override_project_ci,
            content: { include: [{
              project: compliance_project.full_path,
              file: namespace_policy_file,
              ref: compliance_project.default_branch_or_main
            }] })
        end

        let(:namespace_policy_content) do
          { stages: %w[build deploy test],
            namespace_policy_job: { stage: 'test', script: 'namespace script' } }
        end

        it 'responds with error', :aggregate_failures do
          expect(execute).to be_error
          expect(execute.payload).to be_persisted
          expect(execute.payload.errors.full_messages)
            .to contain_exactly(
              "Pipeline execution policy error: Policy `#{namespace_policy[:name]}` could not be applied. " \
                "Its stages are incompatible with stages of another `override_project_ci` policy: " \
                ".pipeline-policy-pre, .pre, build, test, policy-test, deploy, .post, .pipeline-policy-post."
            )
        end
      end
    end

    context 'and Scan Execution Policy is additionally applied on the project' do
      let(:scan_execution_policy) do
        build(:scan_execution_policy, actions: [{ scan: 'secret_detection' }])
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

      it 'persists both pipeline execution policy and scan execution policy jobs', :aggregate_failures do
        expect { execute }.to change { Ci::Build.count }.from(0).to(3)

        expect(execute).to be_success
        expect(execute.payload).to be_persisted

        stages = execute.payload.stages
        expect(stages.map(&:name)).to contain_exactly('build', 'test')

        expect(stages.find_by(name: 'build').builds.map(&:name)).to contain_exactly('namespace_policy_job')
        expect(stages.find_by(name: 'test').builds.map(&:name))
          .to contain_exactly('project_policy_job', 'secret-detection-0')
      end
    end

    context 'and the project has an invalid .gitlab-ci.yml' do
      let(:project_ci_yaml) do
        <<~YAML
          I'm invalid
        YAML
      end

      it 'creates the pipeline successfully' do
        expect { execute }.to change { Ci::Build.count }.from(0).to(2)
      end
    end

    context 'and policy workflow rules prevent the pipeline from being created' do
      let(:namespace_policy_content) do
        {
          workflow: {
            rules: [{ when: 'never' }]
          },
          policy_job: { stage: 'build', script: 'namespace script' }
        }
      end

      let(:project_policy_content) do
        {
          workflow: {
            rules: [{ when: 'never' }]
          },
          policy_job: { stage: 'build', script: 'project script' }
        }
      end

      it 'responds with error and does not create the pipeline', :aggregate_failures do
        expect(execute).to be_error
        expect(execute.payload).not_to be_persisted
        expect(execute.payload.errors.full_messages).to contain_exactly 'Missing CI config file'
      end
    end
  end

  describe 'reserved stages' do
    context 'when policy pipelines use reserved stages' do
      let(:namespace_policy_content) do
        { namespace_pre_job: { stage: '.pipeline-policy-pre', script: 'pre script' } }
      end

      let(:project_policy_content) do
        { project_post_job: { stage: '.pipeline-policy-post', script: 'post script' } }
      end

      it 'responds with success' do
        expect(execute).to be_success
      end

      it 'persists pipeline' do
        expect(execute.payload).to be_persisted
      end

      it 'persists jobs in the reserved stages', :aggregate_failures do
        expect { execute }.to change { Ci::Build.count }.from(0).to(4)

        stages = execute.payload.stages
        expect(stages.map(&:name)).to contain_exactly('.pipeline-policy-pre', 'build', 'test', '.pipeline-policy-post')

        expect(stages.find_by(name: '.pipeline-policy-pre').builds.map(&:name)).to contain_exactly('namespace_pre_job')
        expect(stages.find_by(name: 'build').builds.map(&:name)).to contain_exactly('build')
        expect(stages.find_by(name: 'test').builds.map(&:name)).to contain_exactly('rspec')
        expect(stages.find_by(name: '.pipeline-policy-post').builds.map(&:name)).to contain_exactly('project_post_job')
      end
    end

    context 'when reserved stages are declared in project CI YAML' do
      let(:project_ci_yaml) do
        <<~YAML
          pre-compliance:
            stage: .pipeline-policy-pre
            script:
              - echo 'pre'
          rspec:
            stage: test
            script:
              - echo 'rspec'
          post-compliance:
            stage: .pipeline-policy-post
            script:
              - echo 'post'
        YAML
      end

      it 'responds with error', :aggregate_failures do
        expect(execute).to be_error
        expect(execute.payload).to be_persisted
        expect(execute.payload.errors.full_messages)
          .to contain_exactly(
            'pre-compliance job: chosen stage `.pipeline-policy-pre` is reserved for Pipeline Execution Policies'
          )
      end
    end
  end

  describe 'injected custom stages with `inject_policy` strategy' do
    let(:namespace_policy_content) do
      { stages: %w[build policy-build], namespace_build_job: { stage: 'policy-build', script: 'policy build script' } }
    end

    let(:project_policy_content) do
      { stages: %w[test policy-test], project_test_job: { stage: 'policy-test', script: 'policy test script' } }
    end

    let(:project_policy) do
      build(:pipeline_execution_policy, :inject_policy,
        content: { include: [{
          project: compliance_project.full_path,
          file: project_policy_file,
          ref: compliance_project.default_branch_or_main
        }] })
    end

    let(:namespace_policy) do
      build(:pipeline_execution_policy, :inject_policy,
        content: { include: [{
          project: compliance_project.full_path,
          file: namespace_policy_file,
          ref: compliance_project.default_branch_or_main
        }] })
    end

    it 'responds with success and persists jobs in the policy stages', :aggregate_failures do
      expect { execute }.to change { Ci::Build.count }.from(0).to(4)
      expect(execute).to be_success
      expect(execute.payload).to be_persisted

      stages = execute.payload.stages
      expect(stages.map(&:name)).to contain_exactly('build', 'policy-build', 'test', 'policy-test')

      expect(stages.find_by(name: 'build').builds.map(&:name)).to contain_exactly('build')
      expect(stages.find_by(name: 'policy-build').builds.map(&:name)).to contain_exactly('namespace_build_job')
      expect(stages.find_by(name: 'test').builds.map(&:name)).to contain_exactly('rspec')
      expect(stages.find_by(name: 'policy-test').builds.map(&:name)).to contain_exactly('project_test_job')
    end

    context 'when policy stages specify stages not found in the project' do
      let(:project_policy_content) do
        { stages: %w[build compile check test policy-test publish deploy],
          project_test_job: { stage: 'policy-test', script: 'policy test script' } }
      end

      it 'responds with success and ignores not used stages', :aggregate_failures do
        expect { execute }.to change { Ci::Build.count }.from(0).to(4)
        expect(execute).to be_success
        expect(execute.payload).to be_persisted

        stages = execute.payload.stages
        expect(stages.map(&:name)).to contain_exactly('build', 'policy-build', 'test', 'policy-test')

        expect(stages.find_by(name: 'build').builds.map(&:name)).to contain_exactly('build')
        expect(stages.find_by(name: 'policy-build').builds.map(&:name)).to contain_exactly('namespace_build_job')
        expect(stages.find_by(name: 'test').builds.map(&:name)).to contain_exactly('rspec')
        expect(stages.find_by(name: 'policy-test').builds.map(&:name)).to contain_exactly('project_test_job')
      end
    end

    context 'when policy stages specify reserved stages' do
      let(:namespace_policy_content) do
        { stages: %w[policy-build .pipeline-policy-pre],
          namespace_build_job: { stage: 'policy-build', script: 'policy build script' },
          namespace_pre_job: { stage: '.pipeline-policy-pre', script: 'policy pre script' } }
      end

      let(:project_policy_content) do
        { stages: %w[.pipeline-policy-post policy-test],
          project_test_job: { stage: 'policy-test', script: 'policy test script' },
          project_post_job: { stage: '.pipeline-policy-post', script: 'policy post script' } }
      end

      # Reconsider this result https://gitlab.com/gitlab-org/gitlab/-/issues/514931
      it 'responds with success and enforces reserved stages positions', :aggregate_failures do
        expect { execute }.to change { Ci::Build.count }.from(0).to(6)
        expect(execute).to be_success
        expect(execute.payload).to be_persisted

        stages = execute.payload.stages
        expect(stages.sort_by(&:position).map(&:name))
          .to eq(%w[.pipeline-policy-pre build test policy-test policy-build .pipeline-policy-post])

        expect(stages.find_by(name: '.pipeline-policy-pre').builds.map(&:name)).to contain_exactly('namespace_pre_job')
        expect(stages.find_by(name: 'build').builds.map(&:name)).to contain_exactly('build')
        expect(stages.find_by(name: 'policy-build').builds.map(&:name)).to contain_exactly('namespace_build_job')
        expect(stages.find_by(name: 'test').builds.map(&:name)).to contain_exactly('rspec')
        expect(stages.find_by(name: 'policy-test').builds.map(&:name)).to contain_exactly('project_test_job')
        expect(stages.find_by(name: '.pipeline-policy-post').builds.map(&:name)).to contain_exactly('project_post_job')
      end
    end

    context 'when there are cyclic dependencies' do
      let(:project_ci_yaml) do
        <<~YAML
          stages: [policy-test, test]
          rspec:
            stage: test
            script:
              - echo 'rspec'
        YAML
      end

      it 'responds with error', :aggregate_failures do
        expect(execute).to be_error
        expect(execute.payload).to be_persisted
        expect(execute.payload.errors.full_messages)
          .to contain_exactly(
            /^Pipeline execution policy error: Cyclic dependencies detected when enforcing policies./)
      end
    end
  end

  context 'when policy content does not match the valid schema' do
    # A valid `content` should reference an external file via `include` and not include the jobs in the policy directly
    # The schema is defined in `ee/app/validators/json_schemas/security_orchestration_policy.json`.
    let(:namespace_policy) { build(:pipeline_execution_policy, content: namespace_policy_content) }
    let(:project_policy) { build(:pipeline_execution_policy, content: project_policy_content) }

    it 'responds with success' do
      expect(execute).to be_success
    end

    it 'persists pipeline' do
      expect(execute.payload).to be_persisted
    end

    it 'only includes project jobs and ignores the invalid policy jobs', :aggregate_failures do
      expect { execute }.to change { Ci::Build.count }.from(0).to(2)

      stages = execute.payload.stages
      expect(stages.map(&:name)).to contain_exactly('build', 'test')

      expect(stages.find_by(name: 'build').builds.map(&:name)).to contain_exactly('build')
      expect(stages.find_by(name: 'test').builds.map(&:name)).to contain_exactly('rspec')
    end
  end

  describe 'variables' do
    let(:opts) { { variables_attributes: [{ key: 'TEST_TOKEN', value: 'run token' }] } }
    let(:project_ci_yaml) do
      <<~YAML
        variables:
          TEST_TOKEN: 'global token'
        project-build:
          stage: build
          variables:
            TEST_TOKEN: 'job token'
          script:
            - echo 'build'
        project-test:
          stage: test
          script:
            - echo 'test'
      YAML
    end

    let(:project_policy_content) do
      {
        project_policy_job: {
          variables: { 'TEST_TOKEN' => 'project policy token' },
          script: 'project script'
        }
      }
    end

    let(:namespace_policy_content) do
      {
        namespace_policy_job: {
          variables: { 'TEST_TOKEN' => 'namespace policy token', 'POLICY_TOKEN' => 'namespace policy token' },
          script: 'namespace script'
        }
      }
    end

    it 'applies the policy variables in policy jobs with highest precedence', :aggregate_failures do
      stages = execute.payload.stages

      build_stage = stages.find_by(name: 'build')
      test_stage = stages.find_by(name: 'test')

      project_policy_job = test_stage.builds.find_by(name: 'project_policy_job')
      expect(get_job_variable(project_policy_job, 'TEST_TOKEN')).to eq('project policy token')

      namespace_policy_job = test_stage.builds.find_by(name: 'namespace_policy_job')
      expect(get_job_variable(namespace_policy_job, 'TEST_TOKEN')).to eq('namespace policy token')

      project_build_job = build_stage.builds.find_by(name: 'project-build')
      expect(get_job_variable(project_build_job, 'TEST_TOKEN')).to eq('run token')

      project_test_job = test_stage.builds.find_by(name: 'project-test')
      expect(get_job_variable(project_test_job, 'TEST_TOKEN')).to eq('run token')
    end

    context 'when policies use `variables_override` setting' do
      let(:project_policy) do
        build(:pipeline_execution_policy,
          variables_override: variables_override,
          content: { include: [{
            project: compliance_project.full_path,
            file: project_policy_file,
            ref: compliance_project.default_branch_or_main
          }] })
      end

      context 'when override is allowed' do
        let(:variables_override) { { allowed: true } }

        it 'uses run variables for project policy but not for namespace policy' do
          stages = execute.payload.stages
          test_stage = stages.find_by(name: 'test')

          project_policy_job = test_stage.builds.find_by(name: 'project_policy_job')
          expect(get_job_variable(project_policy_job, 'TEST_TOKEN')).to eq('run token')

          namespace_policy_job = test_stage.builds.find_by(name: 'namespace_policy_job')
          expect(get_job_variable(namespace_policy_job, 'TEST_TOKEN')).to eq('namespace policy token')
        end

        context 'with exception' do
          let(:variables_override) { { allowed: true, exceptions: ['TEST_TOKEN'] } }

          it 'ignores run variables' do
            stages = execute.payload.stages
            test_stage = stages.find_by(name: 'test')

            project_policy_job = test_stage.builds.find_by(name: 'project_policy_job')
            expect(get_job_variable(project_policy_job, 'TEST_TOKEN')).to eq('project policy token')
          end
        end
      end

      context 'when override is disallowed' do
        let(:variables_override) { { allowed: false } }

        it 'ignores run variables for both project and namespace policies' do
          stages = execute.payload.stages
          test_stage = stages.find_by(name: 'test')

          project_policy_job = test_stage.builds.find_by(name: 'project_policy_job')
          expect(get_job_variable(project_policy_job, 'TEST_TOKEN')).to eq('project policy token')

          namespace_policy_job = test_stage.builds.find_by(name: 'namespace_policy_job')
          expect(get_job_variable(namespace_policy_job, 'TEST_TOKEN')).to eq('namespace policy token')
        end

        context 'with exception' do
          let(:variables_override) { { allowed: false, exceptions: ['TEST_TOKEN'] } }

          it 'uses run variables' do
            stages = execute.payload.stages
            test_stage = stages.find_by(name: 'test')

            project_policy_job = test_stage.builds.find_by(name: 'project_policy_job')
            expect(get_job_variable(project_policy_job, 'TEST_TOKEN')).to eq('run token')
          end
        end
      end
    end

    it 'does not leak policy variables into the project jobs and other policy jobs', :aggregate_failures do
      stages = execute.payload.stages

      build_stage = stages.find_by(name: 'build')
      test_stage = stages.find_by(name: 'test')

      project_policy_job = test_stage.builds.find_by(name: 'project_policy_job')
      expect(get_job_variable(project_policy_job, 'POLICY_TOKEN')).to be_nil

      namespace_policy_job = test_stage.builds.find_by(name: 'namespace_policy_job')
      expect(get_job_variable(namespace_policy_job, 'POLICY_TOKEN')).to eq('namespace policy token')

      project_build_job = build_stage.builds.find_by(name: 'project-build')
      expect(get_job_variable(project_build_job, 'POLICY_TOKEN')).to be_nil

      project_test_job = test_stage.builds.find_by(name: 'project-test')
      expect(get_job_variable(project_test_job, 'POLICY_TOKEN')).to be_nil
    end

    context 'when project variables could disable scanners from the included security templates' do
      let(:project_policy_content) do
        {
          include: {
            template: 'Jobs/Secret-Detection.gitlab-ci.yml'
          },
          variables: {
            'SECRET_DETECTION_DISABLED' => 'false'
          }
        }
      end

      before do
        create(:ci_variable, project: project, key: 'SECRET_DETECTION_DISABLED', value: 'true')
      end

      it 'enforces policy variables to prevent scanners from being disabled' do
        stages = execute.payload.stages

        test_stage = stages.find_by(name: 'test')

        expect(test_stage.builds.map(&:name)).to include('secret_detection')
      end
    end

    context 'when using pipeline variables to conditionally run policy jobs' do
      let(:opts) { { variables_attributes: [{ key: 'POLICY_ONLY', value: 'true' }] } }

      let(:project_policy_content) do
        {
          project_policy_job: {
            script: 'project script'
          }
        }
      end

      let(:namespace_policy_content) do
        {
          namespace_policy_job: {
            rules: [{ if: '$POLICY_ONLY == "true"', when: 'never' }, { when: 'always' }],
            script: 'namespace script'
          }
        }
      end

      it 'creates pipeline without namespace_policy_job', :aggregate_failures do
        expect { execute }.to change { Ci::Build.count }.from(0).to(3)

        stages = execute.payload.stages
        expect(stages.map(&:name)).to contain_exactly('build', 'test')

        expect(stages.find_by(name: 'build').builds.map(&:name)).to contain_exactly('project-build')
        expect(stages.find_by(name: 'test').builds.map(&:name)).to contain_exactly('project_policy_job', 'project-test')
      end
    end

    context 'when variable defined in the policy is referencing itself' do
      let(:project_policy_content) do
        {
          project_policy_job: {
            variables: { 'SAMPLE_VARIABLE' => '$SAMPLE_VARIABLE' },
            script: 'project script'
          }
        }
      end

      it 'does not cause circular variable reference error', :aggregate_failures do
        expect { execute }.to change { Ci::Build.count }.from(0).to(4)
        expect(execute).to be_success
        expect(execute.payload).to be_persisted

        test_stage = execute.payload.stages.find_by(name: 'test')
        project_policy_job = test_stage.builds.find_by(name: 'project_policy_job')
        expect(get_job_variable(project_policy_job, 'SAMPLE_VARIABLE')).to eq('$SAMPLE_VARIABLE')
      end
    end
  end

  context 'when running from a schedule' do
    let(:opts) { { schedule: schedule } }
    let(:schedule) { create(:ci_pipeline_schedule, project: project, owner: user) }

    let(:namespace_policy_content) do
      {
        namespace_policy_job: {
          rules: [{ if: '$SCHEDULE_VARIABLE == "schedule"' }],
          script: 'namespace script'
        }
      }
    end

    before do
      schedule.variables << create(:ci_pipeline_schedule_variable, key: 'SCHEDULE_VARIABLE', value: 'schedule')
    end

    it 'creates pipeline with namespace_policy_job', :aggregate_failures do
      expect { execute }.to change { Ci::Build.count }

      stages = execute.payload.stages
      expect(stages.find_by(name: 'test').builds.map(&:name)).to include('namespace_policy_job')
    end
  end

  context 'when running for a merge request' do
    let_it_be(:merge_request) do
      create(:merge_request, source_project: project, target_project: project,
        source_branch: 'feature', target_branch: 'master')
    end

    let(:source) { :merge_request_event }
    let(:opts) { { merge_request: merge_request } }
    let(:params) do
      { ref: merge_request.ref_path,
        source_sha: merge_request.source_branch_sha,
        target_sha: merge_request.target_branch_sha,
        checkout_sha: merge_request.diff_head_sha }
    end

    let(:project_policy_content) do
      {
        project_policy_job: {
          rules: [{ if: '$CI_MERGE_REQUEST_TARGET_BRANCH_SHA' }],
          script: 'project script'
        }
      }
    end

    let(:namespace_policy_content) do
      {
        namespace_policy_job: {
          rules: [{ if: '$CI_MERGE_REQUEST_SOURCE_BRANCH_SHA' }],
          script: 'namespace script'
        }
      }
    end

    before do
      project.update!(merge_pipelines_enabled: true)
      stub_licensed_features(merge_pipelines: true, security_orchestration_policies: true)
      stub_ci_pipeline_yaml_file(project_ci_yaml)
    end

    it 'creates pipeline with policy jobs', :aggregate_failures do
      expect { execute }.to change { Ci::Build.count }.by(2)

      stages = execute.payload.stages
      test_stage = stages.find_by(name: 'test')
      expect(test_stage.builds.map(&:name)).to include('namespace_policy_job', 'project_policy_job')

      project_policy_job = test_stage.builds.find_by(name: 'project_policy_job')
      expect(get_job_variable(project_policy_job, 'CI_MERGE_REQUEST_TARGET_BRANCH_SHA'))
        .to eq(merge_request.target_branch_sha)

      namespace_policy_job = test_stage.builds.find_by(name: 'namespace_policy_job')
      expect(get_job_variable(namespace_policy_job, 'CI_MERGE_REQUEST_SOURCE_BRANCH_SHA'))
        .to eq(merge_request.source_branch_sha)
    end
  end

  context 'when both Scan Execution Policy and Pipeline Execution Policy are applied on the project' do
    let(:scan_execution_policy) do
      build(:scan_execution_policy, actions: [{ scan: 'secret_detection' }])
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

    it 'persists both pipeline execution policy and scan execution policy jobs', :aggregate_failures do
      expect { execute }.to change { Ci::Build.count }.from(0).to(5)

      expect(execute).to be_success
      expect(execute.payload).to be_persisted

      stages = execute.payload.stages
      expect(stages.map(&:name)).to contain_exactly('build', 'test')

      expect(stages.find_by(name: 'build').builds.map(&:name)).to contain_exactly('build', 'namespace_policy_job')
      expect(stages.find_by(name: 'test').builds.map(&:name))
        .to contain_exactly('rspec', 'project_policy_job', 'secret-detection-0')
    end
  end

  context 'when project CI configuration is missing' do
    let(:project_ci_yaml) { nil }

    it 'responds with success' do
      expect(execute).to be_success
    end

    it 'persists pipeline' do
      expect(execute.payload).to be_persisted
    end

    it 'sets the correct config_source' do
      expect(execute.payload.config_source).to eq('pipeline_execution_policy_forced')
    end

    it 'injects the policy jobs', :aggregate_failures do
      expect { execute }.to change { Ci::Build.count }.from(0).to(2)

      stages = execute.payload.stages
      expect(stages.map(&:name)).to contain_exactly('build', 'test')

      expect(stages.find_by(name: 'build').builds.map(&:name)).to contain_exactly('namespace_policy_job')
      expect(stages.find_by(name: 'test').builds.map(&:name)).to contain_exactly('project_policy_job')
    end

    context 'when both Scan Execution Policy and Pipeline Execution Policy are applied on the project' do
      let(:scan_execution_policy) do
        build(:scan_execution_policy, actions: [{ scan: 'secret_detection' }])
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

      it 'persists both pipeline execution policy and scan execution policy jobs', :aggregate_failures do
        expect { execute }.to change { Ci::Build.count }.from(0).to(3)

        expect(execute).to be_success
        expect(execute.payload).to be_persisted

        stages = execute.payload.stages
        expect(stages.map(&:name)).to contain_exactly('build', 'test')

        expect(stages.find_by(name: 'build').builds.map(&:name)).to contain_exactly('namespace_policy_job')
        expect(stages.find_by(name: 'test').builds.map(&:name))
          .to contain_exactly('project_policy_job', 'secret-detection-0')
      end
    end
  end

  context 'when commit contains a [ci skip] directive' do
    before do
      allow_next_instance_of(Ci::Pipeline) do |instance|
        allow(instance).to receive(:git_commit_message).and_return('some message[ci skip]')
      end
    end

    it 'does not skip pipeline creation and injects policy jobs' do
      expect { execute }.to change { Ci::Build.count }.from(0).to(4)

      stages = execute.payload.stages
      expect(stages.find_by(name: 'build').builds.map(&:name)).to contain_exactly('build', 'namespace_policy_job')
      expect(stages.find_by(name: 'test').builds.map(&:name)).to contain_exactly('rspec', 'project_policy_job')
    end

    context 'when policies allow skip_ci' do
      let(:namespace_policy) do
        build(:pipeline_execution_policy, :skip_ci_allowed,
          content: { include: [{
            project: compliance_project.full_path,
            file: namespace_policy_file,
            ref: compliance_project.default_branch_or_main
          }] })
      end

      let(:project_policy) do
        build(:pipeline_execution_policy, :skip_ci_allowed,
          content: { include: [{
            project: compliance_project.full_path,
            file: project_policy_file,
            ref: compliance_project.default_branch_or_main
          }] })
      end

      it 'skips the pipeline', :aggregate_failures do
        expect { execute }.not_to change { Ci::Build.count }
        expect(execute).to be_success
        expect(execute.payload).to be_skipped
      end

      context 'when there are additionally scan execution policies' do
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

        context 'when they disallow skip_ci' do
          let(:scan_execution_policy) do
            build(:scan_execution_policy, :skip_ci_disallowed, actions: [{ scan: 'secret_detection' }])
          end

          it 'does not skip pipeline creation and injects policy jobs', :aggregate_failures do
            expect { execute }.to change { Ci::Build.count }.from(0).to(5)

            stages = execute.payload.stages
            expect(stages.find_by(name: 'build').builds.map(&:name)).to contain_exactly('build', 'namespace_policy_job')
            expect(stages.find_by(name: 'test').builds.map(&:name))
              .to contain_exactly('rspec', 'project_policy_job', 'secret-detection-0')
          end
        end

        context 'when they allow skip_ci' do
          let(:scan_execution_policy) do
            build(:scan_execution_policy, :skip_ci_allowed, actions: [{ scan: 'secret_detection' }])
          end

          it 'skips the pipeline', :aggregate_failures do
            expect { execute }.not_to change { Ci::Build.count }
            expect(execute).to be_success
            expect(execute.payload).to be_skipped
          end
        end
      end
    end
  end

  describe 'access to policy configs inside security policy project repository' do
    let(:namespace_policy) do
      build(:pipeline_execution_policy,
        content: { include: [{
          project: namespace_policies_project.full_path,
          file: namespace_policy_file,
          ref: namespace_policies_project.default_branch_or_main
        }] })
    end

    let(:project_policy) do
      build(:pipeline_execution_policy,
        content: { include: [{
          project: project_policies_project.full_path,
          file: project_policy_file,
          ref: project_policies_project.default_branch_or_main
        }] })
    end

    around do |example|
      create_and_delete_files(
        project_policies_project, { project_policy_file => project_policy_content.to_yaml }
      ) do
        create_and_delete_files(
          namespace_policies_project, { namespace_policy_file => namespace_policy_content.to_yaml }
        ) do
          example.run
        end
      end
    end

    context 'when user does not have access to the policy repository' do
      before do
        project_policies_project.project_setting.update!(spp_repository_pipeline_access: false)
      end

      it 'responds with error' do
        expect(execute).to be_error
        expect(execute.payload.errors.full_messages)
          .to contain_exactly(
            "Pipeline execution policy error: Project `#{project_policies_project.full_path}` not found " \
              "or access denied! Make sure any includes in the pipeline configuration are correctly defined.")
      end

      context 'when security policy projects have the project setting `spp_repository_pipeline_access` enabled' do
        before do
          project_policies_project.project_setting.update!(spp_repository_pipeline_access: true)
          namespace_policies_project.project_setting.update!(spp_repository_pipeline_access: true)
        end

        it 'responds with success' do
          expect(execute).to be_success
        end
      end

      context 'when group has setting `spp_repository_pipeline_access` enabled' do
        before do
          group.namespace_settings.update!(spp_repository_pipeline_access: true)
          project_policies_project.project_setting.update!(spp_repository_pipeline_access: nil)
        end

        it 'responds with success' do
          expect(execute).to be_success
        end
      end

      context 'when application setting `spp_repository_pipeline_access` is enabled' do
        before do
          group.namespace_settings.update!(spp_repository_pipeline_access: nil)
          project_policies_project.project_setting.update!(spp_repository_pipeline_access: nil)
          stub_application_setting(spp_repository_pipeline_access: true)
        end

        it 'responds with success' do
          expect(execute).to be_success
        end
      end
    end
  end

  context 'with pipeline triggered via chat command' do
    let(:source) { :chat }
    let(:chat_name) { create(:chat_name) }
    let(:params) do
      {
        ref: 'master',
        chat_data: {
          chat_name: chat_name,
          name: 'spinach',
          arguments: 'foo',
          command: :project_policy_job,
          response_url: 'https://example.com'
        }
      }
    end

    it 'creates the pipeline', :aggregate_failures do
      expect { execute }.to change { Ci::Build.count }.by(1)

      expect(execute).to be_success
      expect(execute.payload).to be_persisted

      test_stage = execute.payload.stages.find_by(name: 'test')
      expect(test_stage.builds.map(&:name)).to include('project_policy_job')
    end
  end

  private

  def get_job_variable(job, key)
    job.scoped_variables.to_hash[key]
  end
end
