# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::ComplianceManagement::SecurityPolicies::ScanResultPolicyResolver, feature_category: :security_policy_management do
  include GraphqlHelpers
  let_it_be(:current_user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be_with_reload(:framework) { create(:compliance_framework) }
  let_it_be_with_reload(:policy_configuration) do
    create(:security_orchestration_policy_configuration, project: project)
  end

  let_it_be(:compliance_framework_security_policy) do
    create(:compliance_framework_security_policy, policy_configuration: policy_configuration, framework: framework)
  end

  let(:policy_scope) { { compliance_frameworks: [{ id: framework.id }] } }
  let(:policy) { build(:approval_policy, name: 'Enforce approvals', policy_scope: policy_scope) }
  let(:policy_content) { { approval_policy: [policy] } }

  describe '#resolve' do
    subject(:resolve_policies) do
      sync(resolve(described_class, obj: framework, args: {}, ctx: { current_user: current_user }))
    end

    context 'when user is unauthorized' do
      it 'returns nil' do
        expect(resolve_policies).to be_empty
      end
    end

    context 'when user is authorized' do
      let(:expected_response) do
        [
          {
            name: policy[:name],
            description: policy[:description],
            edit_path: Gitlab::Routing.url_helpers.edit_project_security_policy_url(
              project, id: CGI.escape(policy[:name]), type: 'approval_policy'
            ),
            enabled: policy[:enabled],
            policy_scope: {
              compliance_frameworks: [framework],
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
              approval_settings: policy[:approval_settings],
              fallback_behavior: policy[:fallback_behavior],
              metadata: policy[:metadata],
              policy_tuning: policy[:policy_tuning]
            }.compact.deep_stringify_keys),
            updated_at: policy_configuration.policy_last_updated_at,
            action_approvers: [{ all_groups: [], groups: [], roles: [], users: [], custom_roles: [] }],
            user_approvers: [],
            all_group_approvers: [],
            deprecated_properties: [],
            role_approvers: [],
            custom_roles: [],
            source: {
              inherited: false,
              namespace: nil,
              project: project
            },
            csp: false
          }
        ]
      end

      before_all do
        project.add_owner(current_user)
      end

      before do
        stub_licensed_features(security_orchestration_policies: true)

        allow_next_instance_of(Repository) do |repository|
          allow(repository).to receive(:blob_data_at).and_return(policy_content.to_yaml)
        end
      end

      it 'returns the policy' do
        expect(resolve_policies).to match_array(expected_response)
      end
    end
  end
end
