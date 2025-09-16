# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/MultipleMemoizedHelpers -- We need extra helpers to define tables
RSpec.describe Gitlab::BackgroundMigration::BackfillApprovalPolicyRuleIds, feature_category: :security_policy_management do
  let(:security_orchestration_policy_configurations) { table(:security_orchestration_policy_configurations) }
  let(:scan_result_policies) { table(:scan_result_policies) }
  let(:namespaces) { table(:namespaces) }
  let(:security_policies) { table(:security_policies) }
  let(:approval_policy_rules) { table(:approval_policy_rules) }
  let(:security_policy_project_links) { table(:security_policy_project_links) }
  let(:approval_policy_rule_project_links) { table(:approval_policy_rule_project_links) }

  let(:approval_project_rules) { table(:approval_project_rules) }
  let(:approval_merge_request_rules) { table(:approval_merge_request_rules) }
  let(:software_license_policies) { table(:software_license_policies) }
  let(:scan_result_policy_violations) { table(:scan_result_policy_violations) }

  let(:args) do
    min, max = scan_result_policies.pick('MIN(id)', 'MAX(id)')

    {
      start_id: min,
      end_id: max,
      batch_table: 'scan_result_policies',
      batch_column: 'id',
      sub_batch_size: 100,
      pause_ms: 0,
      connection: ApplicationRecord.connection
    }
  end

  let!(:organization) { table(:organizations).create!(name: 'organization', path: 'organization') }

  let!(:group_namespace) do
    namespaces.create!(
      organization_id: organization.id,
      name: 'gitlab-org',
      path: 'gitlab-org',
      type: 'Group'
    ).tap { |namespace| namespace.update!(traversal_ids: [namespace.id]) }
  end

  let(:scan_finding_rule) do
    {
      type: 'scan_finding',
      branches: [],
      scanners: %w[container_scanning],
      vulnerabilities_allowed: 0,
      severity_levels: %w[critical],
      vulnerability_states: %w[detected],
      vulnerability_attributes: []
    }
  end

  let(:license_finding_rule) do
    {
      type: 'license_finding',
      branches: [],
      match_on_inclusion_license: true,
      license_types: %w[BSD MIT],
      license_states: %w[newly_detected detected]
    }
  end

  let(:any_merge_request_rule) do
    {
      type: 'any_merge_request',
      branches: [],
      commits: 'unsigned'
    }
  end

  # rubocop:disable RSpec/FactoriesInMigrationSpecs -- This uses a factory to build a security policy yaml.
  # The yaml file follows the security policy schema (ee/app/validators/json_schemas/security_orchestration_policy.json)
  # We use the current schema in the background migration because we are not
  # introducing breaking changes outside of major milestones.
  let(:approval_policy) do
    build(:approval_policy, name: 'Require approvals',
      rules: [scan_finding_rule, license_finding_rule, any_merge_request_rule])
  end
  # rubocop:enable RSpec/FactoriesInMigrationSpecs

  let(:policies) { { approval_policy: [approval_policy] } }

  let!(:project) { create_project('project', group_namespace) }
  let!(:policy_project) { create_project('policy_project', group_namespace) }

  let!(:security_policy_config) do
    security_orchestration_policy_configurations.create!(
      security_policy_management_project_id: policy_project.id,
      project_id: project.id
    )
  end

  let!(:security_policy) { create_policy(approval_policy, 0) }

  let!(:scan_result_policy) do
    scan_result_policies.create!(
      project_id: project.id,
      security_orchestration_policy_configuration_id: security_policy_config.id,
      orchestration_policy_idx: 0,
      rule_idx: 0
    )
  end

  let!(:merge_request) do
    table(:merge_requests).create!(target_project_id: project.id, target_branch: 'main', source_branch: 'not-main')
  end

  let!(:approval_project_rule) do
    approval_project_rules.create!(
      project_id: project.id,
      name: 'Approval Rule',
      scan_result_policy_id: scan_result_policy.id,
      security_orchestration_policy_configuration_id: security_policy_config.id
    )
  end

  let!(:approval_merge_request_rule) do
    approval_merge_request_rules.create!(
      project_id: project.id,
      name: 'Approval Rule',
      merge_request_id: merge_request.id,
      scan_result_policy_id: scan_result_policy.id,
      security_orchestration_policy_configuration_id: security_policy_config.id
    )
  end

  let!(:mit_license) { table(:software_licenses).create!(name: 'MIT License', spdx_identifier: 'MIT') }

  let!(:software_license_policy) do
    software_license_policies.create!(
      project_id: project.id,
      software_license_id: mit_license.id,
      scan_result_policy_id: scan_result_policy.id
    )
  end

  let!(:scan_result_policy_violation) do
    scan_result_policy_violations.create!(
      project_id: project.id,
      merge_request_id: merge_request.id,
      scan_result_policy_id: scan_result_policy.id
    )
  end

  let!(:approval_policy_rule_scan_finding) do
    approval_policy_rules.create!(
      type: 0,
      security_policy_id: security_policy.id,
      rule_index: 0,
      security_policy_management_project_id: policy_project.id
    )
  end

  let!(:approval_policy_rule_license_finding) do
    approval_policy_rules.create!(
      type: 1,
      security_policy_id: security_policy.id,
      rule_index: 1,
      security_policy_management_project_id: policy_project.id
    )
  end

  let!(:approval_policy_rule_any_merge_request) do
    approval_policy_rules.create!(
      type: 2,
      security_policy_id: security_policy.id,
      rule_index: 2,
      security_policy_management_project_id: policy_project.id
    )
  end

  before do
    allow_next_instance_of(::Gitlab::BackgroundMigration::BackfillApprovalPolicyRuleIds::Repository) do |repository|
      allow(repository).to receive(:blob_data_at).and_return(policies.to_yaml)
    end
  end

  subject(:perform_migration) { described_class.new(**args).perform }

  describe '#perform' do
    before do
      security_policy_project_links.create!(project_id: project.id, security_policy_id: security_policy.id)
    end

    context 'when approval policy rule exists' do
      it 'backfills approval_policy_rule_id for scan_result_policy and associated records' do
        perform_migration

        expect(scan_result_policy.reload.approval_policy_rule_id).to eq(approval_policy_rule_scan_finding.id)
        expect(approval_project_rule.reload.approval_policy_rule_id).to eq(approval_policy_rule_scan_finding.id)
        expect(approval_merge_request_rule.reload.approval_policy_rule_id).to eq(approval_policy_rule_scan_finding.id)
        expect(software_license_policy.reload.approval_policy_rule_id).to eq(approval_policy_rule_scan_finding.id)
        expect(scan_result_policy_violation.reload.approval_policy_rule_id).to eq(approval_policy_rule_scan_finding.id)
      end
    end

    context 'when approval policy rule does not exist' do
      it 'creates approval policy rules from yaml and backfills ids' do
        approval_policy_rules.delete_all

        expect { perform_migration }.to change { approval_policy_rules.count }.by(3)

        expect(approval_policy_rules.all.map(&:type)).to match_array([0, 1, 2])
        expect(approval_policy_rules.all.map(&:security_policy_id)).to match_array([security_policy.id] * 3)
        expect(approval_policy_rules.all.map(&:rule_index)).to match_array([0, 1, 2])
        expect(approval_policy_rules.all.map(&:security_policy_management_project_id)).to eq([policy_project.id] * 3)

        approval_policy_rule = approval_policy_rules.first
        expect(scan_result_policy.reload.approval_policy_rule_id).to eq(approval_policy_rule.id)
        expect(approval_project_rule.reload.approval_policy_rule_id).to eq(approval_policy_rule.id)
        expect(approval_merge_request_rule.reload.approval_policy_rule_id).to eq(approval_policy_rule.id)
        expect(software_license_policy.reload.approval_policy_rule_id).to eq(approval_policy_rule.id)
        expect(scan_result_policy_violation.reload.approval_policy_rule_id).to eq(approval_policy_rule.id)
      end
    end

    context 'when security policy is not found' do
      it 'does not update approval_policy_rule_id' do
        security_policy_project_links.delete_all

        perform_migration

        expect(scan_result_policy.reload.approval_policy_rule_id).to be_nil
        expect(approval_project_rule.reload.approval_policy_rule_id).to be_nil
        expect(approval_merge_request_rule.reload.approval_policy_rule_id).to be_nil
        expect(software_license_policy.reload.approval_policy_rule_id).to be_nil
        expect(scan_result_policy_violation.reload.approval_policy_rule_id).to be_nil
      end
    end

    context 'when policy is not found in yaml' do
      let(:policies) { { approval_policy: [] } }

      it 'does not update approval_policy_rule_id' do
        security_policy_project_links.delete_all

        perform_migration

        expect(scan_result_policy.reload.approval_policy_rule_id).to be_nil
        expect(approval_project_rule.reload.approval_policy_rule_id).to be_nil
        expect(approval_merge_request_rule.reload.approval_policy_rule_id).to be_nil
        expect(software_license_policy.reload.approval_policy_rule_id).to be_nil
        expect(scan_result_policy_violation.reload.approval_policy_rule_id).to be_nil
      end
    end

    context 'when rule is not found in yaml' do
      it 'does not update approval_policy_rule_id' do
        scan_result_policy.update!(rule_idx: 999)

        perform_migration

        expect(scan_result_policy.reload.approval_policy_rule_id).to be_nil
        expect(approval_project_rule.reload.approval_policy_rule_id).to be_nil
        expect(approval_merge_request_rule.reload.approval_policy_rule_id).to be_nil
        expect(software_license_policy.reload.approval_policy_rule_id).to be_nil
        expect(scan_result_policy_violation.reload.approval_policy_rule_id).to be_nil
      end
    end
  end

  def create_project(name, group)
    project_namespace = namespaces.create!(
      name: name,
      path: name,
      type: 'Project',
      organization_id: group.organization_id
    )

    table(:projects).create!(
      organization_id: group.organization_id,
      namespace_id: group.id,
      project_namespace_id: project_namespace.id,
      name: name,
      path: name
    )
  end

  def create_policy(policy_hash, policy_index)
    security_policies.create!(
      {
        type: 0,
        policy_index: policy_index,
        name: policy_hash[:name],
        description: policy_hash[:description],
        enabled: policy_hash[:enabled],
        metadata: policy_hash.fetch(:metadata, {}),
        scope: policy_hash.fetch(:policy_scope, {}),
        content: {},
        checksum: Digest::SHA256.hexdigest(policy_hash.to_json),
        security_orchestration_policy_configuration_id: security_policy_config.id,
        security_policy_management_project_id: security_policy_config.security_policy_management_project_id
      }
    )
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
