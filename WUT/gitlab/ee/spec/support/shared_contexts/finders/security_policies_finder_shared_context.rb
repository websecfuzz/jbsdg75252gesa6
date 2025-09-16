# frozen_string_literal: true

RSpec.shared_context 'with security policies information' do
  let_it_be(:group) { create(:group) }
  let_it_be(:object) { create(:project, group: group) }

  let(:relationship) { nil }
  let(:action_scan_types) { nil }
  let(:include_unscoped) { nil }

  let(:policy_scope) { {} }

  let!(:policy_management_project) do
    create(
      :project, :custom_repo,
      files: {
        '.gitlab/security-policies/policy.yml' => policy_yaml
      })
  end

  let!(:policy_configuration) do
    create(
      :security_orchestration_policy_configuration,
      security_policy_management_project: policy_management_project,
      project: object,
      experiments: { pipeline_execution_schedule_policy: { enabled: true } }
    )
  end

  let(:params) do
    {
      relationship: relationship,
      action_scan_types: action_scan_types,
      include_unscoped: include_unscoped
    }
  end

  let(:actor) { create(:user) }
end
