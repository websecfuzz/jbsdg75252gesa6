# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::SecurityOrchestration::SecurityPolicyResolver, feature_category: :security_policy_management do
  include GraphqlHelpers

  include_context 'orchestration policy context'

  let(:approval_policy) { build(:approval_policy, name: 'Approval policy') }
  let(:scan_execution_policy) { build(:scan_execution_policy, name: 'Scan execution policy') }
  let(:vulnerability_management_policy) { build(:vulnerability_management_policy, name: 'Vulnerability management') }
  let(:pipeline_execution_policy) { build(:pipeline_execution_policy, name: 'Pipeline execution policy') }
  let(:args) { {} }
  let(:pipeline_execution_schedule_policy) do
    build(:pipeline_execution_schedule_policy, name: 'Pipeline schedule policy')
  end

  let(:policy_yaml) { build(:orchestration_policy_yaml, approval_policy: [approval_policy]) }

  subject(:resolve_security_policies) do
    resolve(described_class, obj: project, args: args, ctx: { current_user: user })
  end

  shared_examples_for 'resource protected by feature flag "security_policies_combined_list"' do
    before do
      stub_feature_flags(security_policies_combined_list: false)
    end

    it 'returns an error' do
      expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ResourceNotAvailable,
        "`security_policies_combined_list` feature flag is disabled.") do
        resolve_security_policies
      end
    end
  end

  shared_examples_for 'filterable by type' do |type|
    before do
      stub_licensed_features(security_orchestration_policies: true)
      project.add_developer(user)
    end

    context 'with a matching type' do
      let(:args) { { type: type } }

      it { is_expected.to eq(expected_resolved) }
    end
  end

  context 'when scan execution policy type' do
    let(:policy_yaml) { build(:orchestration_policy_yaml, scan_execution_policy: [scan_execution_policy]) }

    let(:expected_resolved) do
      [{
        description: scan_execution_policy[:description],
        edit_path: Gitlab::Routing.url_helpers.edit_project_security_policy_url(
          project, id: CGI.escape(scan_execution_policy[:name]), type: 'scan_execution_policy'
        ),
        enabled: true,
        name: scan_execution_policy[:name],
        policy_attributes: {
          deprecated_properties: [],
          source: {
            inherited: false,
            namespace: nil,
            project: project
          },
          type: "scan_execution_policy"
        },
        policy_scope: {
          compliance_frameworks: [],
          excluding_groups: [],
          excluding_projects: [],
          including_groups: [],
          including_projects: []
        },
        type: "scan_execution_policy",
        updated_at: policy_configuration.policy_last_updated_at,
        csp: false,
        yaml: YAML.dump({
          name: scan_execution_policy[:name],
          description: scan_execution_policy[:description],
          enabled: scan_execution_policy[:enabled],
          policy_scope: scan_execution_policy[:policy_scope],
          actions: scan_execution_policy[:actions],
          rules: scan_execution_policy[:rules],
          metadata: scan_execution_policy[:metadata]
        }.compact.deep_stringify_keys)
      }]
    end

    it_behaves_like 'resource protected by feature flag "security_policies_combined_list"'
    it_behaves_like 'as an orchestration policy' do
      before do
        create(:security_policy, :scan_execution_policy,
          name: scan_execution_policy[:name],
          content: scan_execution_policy.slice(*Security::Policy::POLICY_CONTENT_FIELDS[:scan_execution_policy]),
          security_orchestration_policy_configuration: policy_configuration)
      end

      it_behaves_like 'filterable by type', 'scan_execution_policy'
    end
  end

  context 'when approval policy type' do
    let(:expected_resolved) do
      [{
        description: approval_policy[:description],
        edit_path: Gitlab::Routing.url_helpers.edit_project_security_policy_url(
          project, id: CGI.escape(approval_policy[:name]), type: 'approval_policy'
        ),
        enabled: true,
        name: approval_policy[:name],
        policy_attributes: {
          action_approvers: [{ all_groups: [], custom_roles: [], groups: [], roles: [], users: [] }],
          all_group_approvers: [],
          custom_roles: [],
          deprecated_properties: [],
          role_approvers: [],
          source: {
            inherited: false,
            namespace: nil,
            project: project
          },
          type: "approval_policy",
          user_approvers: []
        },
        policy_scope: {
          compliance_frameworks: [],
          excluding_groups: [],
          excluding_projects: [],
          including_groups: [],
          including_projects: []
        },
        type: "approval_policy",
        updated_at: policy_configuration.policy_last_updated_at,
        csp: false,
        yaml: YAML.dump({
          name: approval_policy[:name],
          description: approval_policy[:description],
          enabled: approval_policy[:enabled],
          policy_scope: approval_policy[:policy_scope],
          actions: approval_policy[:actions],
          rules: approval_policy[:rules],
          approval_settings: approval_policy[:approval_settings],
          fallback_behavior: approval_policy[:fallback_behavior],
          metadata: approval_policy[:metadata],
          policy_tuning: approval_policy[:policy_tuning]
        }.compact.deep_stringify_keys)
      }]
    end

    it_behaves_like 'resource protected by feature flag "security_policies_combined_list"'
    it_behaves_like 'as an orchestration policy' do
      before do
        create(:security_policy, :approval_policy,
          name: approval_policy[:name],
          content: approval_policy.slice(*Security::Policy::POLICY_CONTENT_FIELDS[:approval_policy]),
          security_orchestration_policy_configuration: policy_configuration)
      end

      it_behaves_like 'filterable by type', 'approval_policy'
    end
  end

  context 'when pipeline execution policy type' do
    let(:policy_yaml) { build(:orchestration_policy_yaml, pipeline_execution_policy: [pipeline_execution_policy]) }

    let(:expected_resolved) do
      [{
        description: pipeline_execution_policy[:description],
        edit_path: Gitlab::Routing.url_helpers.edit_project_security_policy_url(
          project, id: CGI.escape(pipeline_execution_policy[:name]), type: 'pipeline_execution_policy'
        ),
        enabled: true,
        name: pipeline_execution_policy[:name],
        policy_attributes: {
          policy_blob_file_path: '',
          source: {
            inherited: false,
            namespace: nil,
            project: project
          },
          type: "pipeline_execution_policy",
          warnings: ["The policy is associated with a non-existing pipeline configuration file."]
        },
        policy_scope: {
          compliance_frameworks: [],
          excluding_groups: [],
          excluding_projects: [],
          including_groups: [],
          including_projects: []
        },
        type: "pipeline_execution_policy",
        updated_at: policy_configuration.policy_last_updated_at,
        csp: false,
        yaml: YAML.dump({
          name: pipeline_execution_policy[:name],
          description: pipeline_execution_policy[:description],
          enabled: pipeline_execution_policy[:enabled],
          policy_scope: pipeline_execution_policy[:policy_scope],
          pipeline_config_strategy: pipeline_execution_policy[:pipeline_config_strategy],
          content: pipeline_execution_policy[:content],
          metadata: pipeline_execution_policy[:metadata],
          suffix: pipeline_execution_policy[:suffix],
          skip_ci: pipeline_execution_policy[:skip_ci]
        }.deep_stringify_keys)
      }]
    end

    it_behaves_like 'resource protected by feature flag "security_policies_combined_list"'
    it_behaves_like 'as an orchestration policy' do
      before do
        create(:security_policy, :pipeline_execution_policy,
          name: pipeline_execution_policy[:name],
          content: pipeline_execution_policy
                     .slice(*Security::Policy::POLICY_CONTENT_FIELDS[:pipeline_execution_policy]),
          security_orchestration_policy_configuration: policy_configuration)
      end

      it_behaves_like 'filterable by type', 'pipeline_execution_policy'
    end
  end

  context 'when pipeline execution schedule policy type' do
    let(:policy_yaml) do
      build(:orchestration_policy_yaml, pipeline_execution_schedule_policy: [pipeline_execution_schedule_policy])
    end

    let(:expected_resolved) do
      [{
        description: pipeline_execution_schedule_policy[:description],
        edit_path: Gitlab::Routing.url_helpers.edit_project_security_policy_url(
          project, id: CGI.escape(pipeline_execution_schedule_policy[:name]), type: 'pipeline_execution_schedule_policy'
        ),
        enabled: true,
        name: pipeline_execution_schedule_policy[:name],
        policy_attributes: {
          policy_blob_file_path: '',
          source: {
            inherited: false,
            namespace: nil,
            project: project
          },
          type: "pipeline_execution_schedule_policy",
          warnings: ["The policy is associated with a non-existing pipeline configuration file."]
        },
        policy_scope: {
          compliance_frameworks: [],
          excluding_groups: [],
          excluding_projects: [],
          including_groups: [],
          including_projects: []
        },
        type: "pipeline_execution_schedule_policy",
        updated_at: policy_configuration.policy_last_updated_at,
        csp: false,
        yaml: YAML.dump({
          name: pipeline_execution_schedule_policy[:name],
          description: pipeline_execution_schedule_policy[:description],
          enabled: pipeline_execution_schedule_policy[:enabled],
          policy_scope: {},
          content: pipeline_execution_schedule_policy[:content],
          schedules: pipeline_execution_schedule_policy[:schedules],
          metadata: pipeline_execution_schedule_policy[:metadata]
        }.compact.deep_stringify_keys)
      }]
    end

    it_behaves_like 'resource protected by feature flag "security_policies_combined_list"'
    it_behaves_like 'as an orchestration policy' do
      before do
        create(:security_policy, :pipeline_execution_schedule_policy,
          name: pipeline_execution_schedule_policy[:name],
          content: pipeline_execution_schedule_policy
                     .slice(*Security::Policy::POLICY_CONTENT_FIELDS[:pipeline_execution_schedule_policy]),
          security_orchestration_policy_configuration: policy_configuration)
      end

      it_behaves_like 'filterable by type', 'pipeline_execution_schedule_policy'
    end
  end

  context 'when vulnerability management policy type' do
    let(:policy_yaml) do
      build(:orchestration_policy_yaml, vulnerability_management_policy: [vulnerability_management_policy])
    end

    let(:expected_resolved) do
      [{
        description: vulnerability_management_policy[:description],
        edit_path: Gitlab::Routing.url_helpers.edit_project_security_policy_url(
          project, id: CGI.escape(vulnerability_management_policy[:name]), type: 'vulnerability_management_policy'
        ),
        enabled: true,
        name: vulnerability_management_policy[:name],
        policy_attributes: {
          source: {
            inherited: false,
            namespace: nil,
            project: project
          },
          type: "vulnerability_management_policy"
        },
        policy_scope: {
          compliance_frameworks: [],
          excluding_groups: [],
          excluding_projects: [],
          including_groups: [],
          including_projects: []
        },
        type: "vulnerability_management_policy",
        updated_at: policy_configuration.policy_last_updated_at,
        csp: false,
        yaml: YAML.dump({
          name: vulnerability_management_policy[:name],
          description: vulnerability_management_policy[:description],
          enabled: vulnerability_management_policy[:enabled],
          policy_scope: vulnerability_management_policy[:policy_scope],
          rules: vulnerability_management_policy[:rules],
          actions: vulnerability_management_policy[:actions]
        }.compact.deep_stringify_keys)
      }]
    end

    it_behaves_like 'resource protected by feature flag "security_policies_combined_list"'
    it_behaves_like 'as an orchestration policy' do
      before do
        create(:security_policy, :vulnerability_management_policy,
          name: vulnerability_management_policy[:name],
          content: vulnerability_management_policy
                     .slice(*Security::Policy::POLICY_CONTENT_FIELDS[:vulnerability_management_policy]),
          security_orchestration_policy_configuration: policy_configuration)
      end

      it_behaves_like 'filterable by type', 'vulnerability_management_policy'
    end
  end
end
