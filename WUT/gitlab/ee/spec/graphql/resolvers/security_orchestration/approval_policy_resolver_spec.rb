# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::SecurityOrchestration::ApprovalPolicyResolver, feature_category: :security_policy_management do
  include GraphqlHelpers

  include_context 'orchestration policy context'

  let(:policy) { build(:approval_policy, name: 'Require security approvals') }
  let(:policy_yaml) { build(:orchestration_policy_yaml, approval_policy: [policy]) }
  let(:expected_resolved) do
    [
      {
        name: 'Require security approvals',
        description: 'This policy considers only container scanning and critical severities',
        edit_path: Gitlab::Routing.url_helpers.edit_project_security_policy_url(
          project, id: CGI.escape(policy[:name]), type: 'approval_policy'
        ),
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
          approval_settings: policy[:approval_settings],
          fallback_behavior: policy[:fallback_behavior],
          metadata: policy[:metadata],
          policy_tuning: policy[:policy_tuning]
        }.compact.deep_stringify_keys),
        updated_at: policy_last_updated_at,
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
        }
      }
    ]
  end

  subject(:resolve_scan_policies) { resolve(described_class, obj: project, ctx: { current_user: user }) }

  it_behaves_like 'as an orchestration policy'
end
