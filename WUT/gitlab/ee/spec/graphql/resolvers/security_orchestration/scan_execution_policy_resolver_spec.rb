# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::SecurityOrchestration::ScanExecutionPolicyResolver, feature_category: :security_policy_management do
  include GraphqlHelpers
  include Security::PolicyCspHelpers

  let_it_be(:group) { create(:group) }
  let!(:policy_configuration) do
    create(
      :security_orchestration_policy_configuration,
      security_policy_management_project: policy_management_project,
      project: project
    )
  end

  let_it_be(:project) { create(:project, group: group) }
  let(:policy) { build(:scan_execution_policy, name: 'Run DAST in every pipeline', actions: actions) }
  let(:actions) { attributes_for(:scan_execution_policy)[:actions] }
  let(:policy_yaml) { build(:orchestration_policy_yaml, scan_execution_policy: [policy]) }

  let!(:policy_management_project) do
    create(
      :project, :custom_repo,
      files: {
        '.gitlab/security-policies/policy.yml' => policy_yaml
      })
  end

  let_it_be(:user) { create(:user) }

  let(:args) { {} }
  let(:deprecated_properties) { [] }
  let(:expected_resolved) do
    [
      {
        name: 'Run DAST in every pipeline',
        description: 'This policy enforces to run DAST for every pipeline within the project',
        edit_path: edit_project_policy_path(project, policy),
        enabled: true,
        policy_scope: {
          compliance_frameworks: [],
          including_projects: [],
          excluding_projects: [],
          including_groups: [],
          excluding_groups: []
        },
        yaml: YAML.dump({
          name: policy[:name],
          description: policy[:description],
          enabled: policy[:enabled],
          policy_scope: policy[:policy_scope],
          actions: policy[:actions],
          rules: policy[:rules],
          metadata: policy[:metadata]
        }.compact.deep_stringify_keys),
        updated_at: policy_configuration.policy_last_updated_at,
        deprecated_properties: deprecated_properties,
        source: {
          project: project,
          namespace: nil,
          inherited: false
        },
        csp: false
      }
    ]
  end

  subject(:resolve_policies) do
    resolve(
      described_class,
      obj: project,
      args: args,
      ctx: { current_user: user },
      arg_style: :internal
    )
  end

  describe '#resolve' do
    context 'when feature is not licensed' do
      before do
        stub_licensed_features(security_orchestration_policies: false)
      end

      it 'returns empty collection' do
        expect(resolve_policies).to be_empty
      end
    end

    context 'when feature is licensed' do
      before do
        stub_licensed_features(security_orchestration_policies: true)
      end

      context 'when policies are available for project only' do
        # project not belonging to a group.
        let_it_be(:project) { create(:project) }

        before do
          project.add_developer(user)
        end

        it 'returns scan execution policies' do
          expect(resolve_policies).to eq(expected_resolved)
        end
      end

      context 'when policies are available for namespace only' do
        let_it_be(:project) { create(:project, group: group) }

        let!(:policy_configuration) { nil }

        let!(:group_policy_configuration) do
          create(
            :security_orchestration_policy_configuration,
            :namespace,
            security_policy_management_project: policy_management_project,
            namespace: group
          )
        end

        before do
          group.add_developer(user)
        end

        context 'when relationship argument is not provided' do
          it 'returns no scan execution policies' do
            expect(resolve_policies).to be_empty
          end
        end

        context 'when relationship argument is provided as DIRECT' do
          let(:args) { { relationship: :direct } }

          it 'returns no scan execution policies' do
            expect(resolve_policies).to be_empty
          end
        end

        context 'when relationship argument is provided as INHERITED' do
          let(:args) { { relationship: :inherited } }

          it 'returns scan execution policies for groups only' do
            expect(resolve_policies).to eq(
              [
                {
                  name: 'Run DAST in every pipeline',
                  description: 'This policy enforces to run DAST for every pipeline within the project',
                  edit_path: edit_group_policy_path(group, policy),
                  enabled: true,
                  policy_scope: {
                    compliance_frameworks: [],
                    including_projects: [],
                    excluding_projects: [],
                    including_groups: [],
                    excluding_groups: []
                  },
                  yaml: YAML.dump({
                    name: policy[:name],
                    description: policy[:description],
                    enabled: policy[:enabled],
                    policy_scope: policy[:policy_scope],
                    actions: policy[:actions],
                    rules: policy[:rules],
                    metadata: policy[:metadata]
                  }.compact.deep_stringify_keys),
                  deprecated_properties: deprecated_properties,
                  updated_at: group_policy_configuration.policy_last_updated_at,
                  source: {
                    project: nil,
                    namespace: group,
                    inherited: true
                  },
                  csp: false
                }
              ])
          end
        end
      end

      context 'when policies are available for project and namespace' do
        let_it_be(:project) { create(:project, group: group) }

        let!(:group_policy_configuration) do
          create(
            :security_orchestration_policy_configuration,
            :namespace,
            security_policy_management_project: policy_management_project,
            namespace: group
          )
        end

        before do
          project.add_developer(user)
          group.add_developer(user)
        end

        context 'when relationship argument is not provided' do
          it 'returns scan execution policies for project only' do
            expect(resolve_policies).to eq(expected_resolved)
          end
        end

        context 'when relationship argument is provided as DIRECT' do
          let(:args) { { relationship: :direct } }

          it 'returns scan execution policies for project only' do
            expect(resolve_policies).to eq(expected_resolved)
          end
        end

        context 'when relationship argument is provided as INHERITED' do
          let(:args) { { relationship: :inherited } }
          let(:expected_resolved_group_policy) do
            {
              name: 'Run DAST in every pipeline',
              description: 'This policy enforces to run DAST for every pipeline within the project',
              edit_path: edit_group_policy_path(group, policy),
              enabled: true,
              policy_scope: {
                compliance_frameworks: [],
                including_projects: [],
                excluding_projects: [],
                including_groups: [],
                excluding_groups: []
              },
              yaml: YAML.dump({
                name: policy[:name],
                description: policy[:description],
                enabled: policy[:enabled],
                policy_scope: policy[:policy_scope],
                actions: policy[:actions],
                rules: policy[:rules],
                metadata: policy[:metadata]
              }.compact.deep_stringify_keys),
              updated_at: group_policy_configuration.policy_last_updated_at,
              deprecated_properties: deprecated_properties,
              source: {
                project: nil,
                namespace: group,
                inherited: true
              },
              csp: false
            }
          end

          it 'returns scan execution policies defined for both project and namespace' do
            expect(resolve_policies).to match_array(
              [
                *expected_resolved,
                expected_resolved_group_policy
              ])
          end

          context 'when the group is a CSP group' do
            before do
              stub_csp_group(group)
            end

            it 'returns the group policy with csp: true' do
              expect(resolve_policies).to match_array(
                [
                  *expected_resolved,
                  expected_resolved_group_policy.merge(csp: true)
                ]
              )
            end
          end
        end
      end

      context 'when user is unauthorized' do
        it 'returns empty collection' do
          expect(resolve_policies).to be_empty
        end
      end
    end
  end

  context 'when action_scan_types is given' do
    before do
      stub_licensed_features(security_orchestration_policies: true)
      project.add_developer(user)
    end

    context 'when there are multiple policies' do
      let(:secret_detection_policy) do
        build(
          :scan_execution_policy,
          name: 'Run secret detection in every pipeline',
          description: 'Secret detection',
          actions: [{ scan: 'secret_detection' }]
        )
      end

      let(:args) { { action_scan_types: [::Types::Security::ReportTypeEnum.values['DAST'].value] } }

      it 'returns policy matching the given scan type' do
        expect(resolve_policies).to eq(expected_resolved)
      end
    end

    context 'when there are no matching policies' do
      let(:args) { { action_scan_types: [::Types::Security::ReportTypeEnum.values['CONTAINER_SCANNING'].value] } }

      it 'returns empty response' do
        expect(resolve_policies).to be_empty
      end
    end
  end

  def edit_project_policy_path(target_project, policy)
    Gitlab::Routing.url_helpers.edit_project_security_policy_url(
      target_project, id: CGI.escape(policy[:name]), type: 'scan_execution_policy'
    )
  end

  def edit_group_policy_path(target_group, policy)
    Gitlab::Routing.url_helpers.edit_group_security_policy_url(
      target_group, id: CGI.escape(policy[:name]), type: 'scan_execution_policy'
    )
  end
end
