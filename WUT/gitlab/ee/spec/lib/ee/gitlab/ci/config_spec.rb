# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Config, feature_category: :pipeline_composition do
  let_it_be(:ci_yml) do
    <<-EOS
    sample_job:
      script:
      - echo 'test'
    EOS
  end

  describe 'with required instance template' do
    let(:template_name) { 'test_template' }
    let(:template_repository) { create(:project, :custom_repo, files: { "gitlab-ci/#{template_name}.yml" => template_yml }) }

    let(:template_yml) do
      <<-EOS
      sample_job:
        script:
          - echo 'not test'
      EOS
    end

    let_it_be_with_refind(:project) { create(:project, :repository) }

    subject(:config) { described_class.new(ci_yml, project: project) }

    before do
      stub_application_setting(file_template_project: template_repository, required_instance_ci_template: template_name)
      stub_licensed_features(custom_file_templates: true, required_ci_templates: true)
    end

    context 'when feature flag is enabled' do
      before do
        stub_feature_flags(required_pipelines: true)
      end

      it 'processes the required includes' do
        expect(config.to_hash[:sample_job][:script]).to eq(["echo 'not test'"])
      end
    end

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(required_pipelines: false)
      end

      it 'does not process the required includes' do
        expect(config.to_hash[:sample_job][:script]).to eq(["echo 'test'"])
      end
    end
  end

  describe 'with security orchestration policy' do
    let(:source) { 'push' }

    let(:ref) { 'master' }
    let_it_be_with_refind(:project) { create(:project, :repository) }

    let_it_be(:policies_repository) { create(:project, :repository) }
    let_it_be(:security_orchestration_policy_configuration) { create(:security_orchestration_policy_configuration, project: project, security_policy_management_project: policies_repository) }
    let_it_be(:policy) { build(:scan_execution_policy) }
    let_it_be(:policy_yaml) { build(:orchestration_policy_yaml, scan_execution_policy: [policy]) }
    let_it_be(:db_policy) do
      create(:security_policy, :scan_execution_policy, linked_projects: [project], content: policy.slice(:actions),
        security_orchestration_policy_configuration: security_orchestration_policy_configuration)
    end

    let(:pipeline) { build(:ci_pipeline, project: project, ref: ref) }
    let(:command) do
      Gitlab::Ci::Pipeline::Chain::Command.new(
        project: project,
        source: source
      )
    end

    let(:pipeline_policy_context) do
      Gitlab::Ci::Pipeline::ExecutionPolicies::PipelineContext.new(project: project, command: command)
    end

    subject(:config) { described_class.new(ci_yml, pipeline: pipeline, project: project, pipeline_policy_context: pipeline_policy_context) }

    before do
      allow_next_instance_of(Repository) do |repository|
        # allow(repository).to receive(:ls_files).and_return(['.gitlab/security-policies/enforce-dast.yml'])
        allow(repository).to receive(:blob_data_at).and_return(policy_yaml)
      end
    end

    context 'when feature is not licensed' do
      it 'does not modify the config' do
        expect(config.to_hash).to eq(sample_job: { script: ["echo 'test'"] })
      end
    end

    context 'when feature is licensed' do
      before do
        stub_licensed_features(security_orchestration_policies: true)
      end

      context 'when policy is not applicable on branch from the pipeline' do
        let(:ref) { 'another-branch' }

        it 'does not modify the config' do
          expect(config.to_hash).to eq(sample_job: { script: ["echo 'test'"] })
        end
      end

      context 'when policy is applicable on branch from the pipeline' do
        let(:ref) { 'master' }

        context 'when DAST profiles are not found' do
          it 'adds a job with error message' do
            expect(config.to_hash).to eq(
              stages: [".pre", "build", "test", "deploy", "dast", ".post"],
              sample_job: { script: ["echo 'test'"] },
              variables: Security::SecurityOrchestrationPolicies::ScanPipelineService::TOP_LEVEL_VARIABLES,
              'dast-on-demand-0': { allow_failure: true, script: 'echo "Error during On-Demand Scan execution: Dast site profile was not provided" && false' }
            )
          end
        end

        context 'when project CI configuration contains top-level variables' do
          let_it_be(:ci_yml) do
            <<-EOS
            variables:
              FOO: 'bar'

            sample_job:
              script:
              - echo 'test'
            EOS
          end

          let_it_be(:top_level_variables) { Security::SecurityOrchestrationPolicies::ScanPipelineService::TOP_LEVEL_VARIABLES }
          let_it_be(:expected_variables) { top_level_variables.merge(FOO: 'bar') }

          it 'retains top-level variables' do
            expect(config.to_hash).to eq(
              stages: [".pre", "build", "test", "deploy", "dast", ".post"],
              sample_job: { script: ["echo 'test'"] },
              variables: expected_variables,
              'dast-on-demand-0': { allow_failure: true, script: 'echo "Error during On-Demand Scan execution: Dast site profile was not provided" && false' }
            )
          end
        end

        context 'when DAST profiles are found' do
          let_it_be(:dast_scanner_profile) { create(:dast_scanner_profile, project: project, name: 'Scanner Profile') }
          let_it_be(:dast_site_profile) { create(:dast_site_profile, project: project, name: 'Site Profile') }

          let(:expected_configuration) do
            {
              sample_job: {
                script: ["echo 'test'"]
              },
              'dast-on-demand-0': {
                stage: 'dast',
                image: { name: '$SECURE_ANALYZERS_PREFIX/dast:$DAST_VERSION$DAST_IMAGE_SUFFIX' },
                variables: {
                  DAST_VERSION: 6,
                  SECURE_ANALYZERS_PREFIX: '$CI_TEMPLATE_REGISTRY_HOST/security-products',
                  DAST_IMAGE_SUFFIX: '',
                  GIT_STRATEGY: 'none'
                },
                allow_failure: true,
                script: ['/analyze'],
                artifacts: { access: 'developer', paths: ["gl-dast-*.*"], reports: { dast: 'gl-dast-report.json' }, when: 'always' },
                dast_configuration: {
                  site_profile: dast_site_profile.name,
                  scanner_profile: dast_scanner_profile.name
                },
                rules: [
                  { if: '$CI_GITLAB_FIPS_MODE == "true"', variables: { DAST_IMAGE_SUFFIX: "-fips" } },
                  { when: 'on_success' }
                ]
              }
            }
          end

          it 'extends config with additional jobs' do
            expect(config.to_hash).to include(expected_configuration)
          end

          context 'when scan_settings is provided with ignore_default_before_after_script set to false' do
            let_it_be(:actions) do
              [
                {
                  scan: 'dast',
                  site_profile: 'Site Profile',
                  scanner_profile: 'Scanner Profile',
                  scan_settings: {
                    ignore_default_before_after_script: false
                  }
                }
              ]
            end

            let_it_be(:policy_yaml) { build(:orchestration_policy_yaml, scan_execution_policy: [build(:scan_execution_policy, actions: actions)]) }

            it 'does not override before_script and after_script with empty array' do
              expect(config.to_hash[:'dast-on-demand-0']).not_to include(before_script: [], after_script: [])
            end
          end

          context 'when scan_settings is provided with ignore_default_before_after_script set to true' do
            let_it_be(:actions) do
              [
                {
                  scan: 'dast',
                  site_profile: 'Site Profile',
                  scanner_profile: 'Scanner Profile',
                  scan_settings: {
                    ignore_default_before_after_script: true
                  }
                }
              ]
            end

            let_it_be(:policy_yaml) { build(:orchestration_policy_yaml, scan_execution_policy: [build(:scan_execution_policy, actions: actions)]) }

            it 'overrides before_script and after_script with empty array' do
              expect(config.to_hash[:'dast-on-demand-0']).to include(before_script: [], after_script: [])
            end
          end

          context 'when in creating_policy_pipeline? is true' do
            include_context 'with pipeline policy context'

            let(:creating_policy_pipeline) { true }

            it 'does not modify the config' do
              expect(config.to_hash).not_to have_key(:'dast-on-demand-0')
            end
          end

          context 'when source is ondemand_dast_scan' do
            let(:source) { 'ondemand_dast_scan' }

            it 'does not modify the config' do
              expect(config.to_hash).to eq(sample_job: { script: ["echo 'test'"] })
            end
          end
        end
      end
    end
  end

  describe '#inject_pipeline_execution_policy_stages' do
    subject(:config) { described_class.new(ci_yml, project: project, pipeline_policy_context: pipeline_policy_context) }

    include_context 'with pipeline policy context'

    let(:default_stages) { %w[.pre build test deploy .post] }
    let(:ci_yml) do
      YAML.dump(
        rspec: {
          script: 'rspec'
        }
      )
    end

    it 'does not inject the reserved stages by default' do
      expect(config.stages).to match_array(default_stages)
    end

    shared_examples_for 'injects reserved policy stages' do
      it 'injects reserved stages into yaml_processor_result' do
        expect(config.stages).to eq(['.pipeline-policy-pre', *default_stages, '.pipeline-policy-post'])
      end

      context 'when the config already specifies reserved stages' do
        let(:ci_yml) do
          YAML.dump(
            stages: ['.pipeline-policy-pre', *default_stages, '.pipeline-policy-post'],
            rspec: {
              script: 'rspec'
            }
          )
        end

        it 'does not inject the reserved stages multiple times' do
          expect(config.stages).to eq(['.pipeline-policy-pre', *default_stages, '.pipeline-policy-post'])
        end
      end
    end

    context 'when execution_policy_mode is true' do
      let(:creating_policy_pipeline) { true }

      it_behaves_like 'injects reserved policy stages'
    end

    context 'when execution_policy_pipelines are present' do
      let(:execution_policy_pipelines) { build_list(:pipeline_execution_policy_pipeline, 2) }

      it_behaves_like 'injects reserved policy stages'

      describe 'custom policy stages' do
        before do
          allow(pipeline_policy_context.pipeline_execution_context)
            .to receive(:injected_policy_stages)
                  .and_return([%w[.pipeline-policy-pre .pre test policy-test deploy .post .pipeline-policy-post]])
        end

        it 'injects policy stages into yaml_processor_result' do
          expect(config.stages)
            .to eq(%w[.pipeline-policy-pre .pre build test policy-test deploy .post .pipeline-policy-post])
        end

        context 'when the config specifies a policy stage in incorrect order' do
          let(:ci_yml) do
            YAML.dump(
              stages: %w[build policy-test test],
              rspec: {
                script: 'rspec'
              }
            )
          end

          it 'raises an error' do
            expect { config.stages }
              .to raise_error(Gitlab::Ci::Config::ConfigError, /Cyclic dependencies/)
          end
        end
      end

      describe 'overriding policies' do
        let(:execution_policy_pipelines) { build_list(:pipeline_execution_policy_pipeline, 2, :override_project_ci) }

        before do
          allow(pipeline_policy_context.pipeline_execution_context)
            .to receive(:override_policy_stages)
                  .and_return(%w[.pipeline-policy-pre .pre policy-test .post .pipeline-policy-post])
        end

        it 'overrides the stages in yaml_processor_result' do
          expect(config.stages)
            .to eq(%w[.pipeline-policy-pre .pre policy-test .post .pipeline-policy-post])
        end

        context 'when creating a policy pipeline' do
          let(:creating_policy_pipeline) { true }

          it 'only injects reserved stages but does not override the project stages' do
            expect(config.stages)
              .to eq(['.pipeline-policy-pre', *default_stages, '.pipeline-policy-post'])
          end
        end
      end
    end
  end
end
