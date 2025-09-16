# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::BackfillSecurityPolicies, feature_category: :security_policy_management do
  let(:security_orchestration_policy_configurations) { table(:security_orchestration_policy_configurations) }
  let(:namespaces) { table(:namespaces) }
  let(:security_policies) { table(:security_policies) }
  let(:scan_execution_policy_rules) { table(:scan_execution_policy_rules) }
  let(:approval_policy_rules) { table(:approval_policy_rules) }
  let(:security_policy_project_links) { table(:security_policy_project_links) }
  let(:approval_policy_rule_project_links) { table(:approval_policy_rule_project_links) }
  let(:vulnerability_management_policy_rules) { table(:vulnerability_management_policy_rules) }
  let(:compliance_management_frameworks) { table(:compliance_management_frameworks) }
  let(:compliance_framework_project_settings) { table(:project_compliance_framework_settings) }

  let(:args) do
    min, max = security_orchestration_policy_configurations.pick('MIN(id)', 'MAX(id)')

    {
      start_id: min,
      end_id: max,
      batch_table: 'security_orchestration_policy_configurations',
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

  let(:policy_scope) { {} }

  # rubocop:disable RSpec/FactoriesInMigrationSpecs -- This uses a factory to build a security policy yaml.
  # The yaml file follows the security policy schema (ee/app/validators/json_schemas/security_orchestration_policy.json)
  # We use the current schema in the background migration because we are not
  # introducing breaking changes outside of major milestones.
  let(:scan_execution_policy) { build(:scan_execution_policy, name: 'Run scans in every pipeline') }
  let(:approval_policy) { build(:approval_policy, name: 'Require approvals', policy_scope: policy_scope) }
  let(:vulnerability_management_policy) { build(:vulnerability_management_policy, name: 'Manage vulnerabilities') }

  let(:pipeline_execution_policy) do
    build(
      :pipeline_execution_policy,
      name: 'Run compliance pipeline',
      content: {
        include: [
          {
            file: 'compliance-pipeline-ci.yml',
            project: 'compliance-project'
          }
        ]
      },
      pipeline_config_strategy: 'inject_ci'
    )
  end
  # rubocop:enable RSpec/FactoriesInMigrationSpecs

  let!(:project) { create_project('project', group_namespace) }
  let!(:policy_project) { create_project('policy_project', group_namespace) }

  let!(:security_policy_config) do
    security_orchestration_policy_configurations.create!(
      security_policy_management_project_id: policy_project.id,
      project_id: project.id
    )
  end

  before do
    allow_next_instance_of(::Gitlab::BackgroundMigration::BackfillSecurityPolicies::Repository) do |repository|
      allow(repository).to receive(:blob_data_at).and_return(policies.to_yaml)
    end
  end

  subject(:perform_migration) { described_class.new(**args).perform }

  context 'with scan execution policies' do
    let(:policies) { { scan_execution_policy: [scan_execution_policy] } }

    it 'creates scan_execution policies', :aggregate_failures do
      expect { perform_migration }.to change { security_policies.count }.by(1)
        .and change { scan_execution_policy_rules.count }.by(1)
        .and change { security_policy_project_links.count }.by(1)
        .and not_change { approval_policy_rule_project_links.count }

      scan_execution_policy = security_policies.last
      scan_execution_policy_rule = scan_execution_policy_rules.last

      expect(scan_execution_policy).to have_attributes(
        type: 1,
        policy_index: 0,
        name: 'Run scans in every pipeline',
        description: 'This policy enforces to run DAST for every pipeline within the project',
        enabled: true,
        metadata: {},
        scope: {},
        content: {
          'actions' => [
            {
              'scan' => 'dast',
              'scanner_profile' => 'Scanner Profile',
              'site_profile' => 'Site Profile'
            }
          ]
        }
      )

      expect(scan_execution_policy_rule).to have_attributes(
        security_policy_id: scan_execution_policy.id,
        type: 0,
        rule_index: 0,
        content: { 'branches' => ['master'] }
      )
    end
  end

  context 'with approval policies' do
    let(:policies) { { approval_policy: [approval_policy] } }

    context 'with multiple rules' do
      # rubocop:disable RSpec/FactoriesInMigrationSpecs -- This uses a factory to build a security policy yaml.
      let(:policies) do
        {
          approval_policy: [build(:approval_policy,
            name: 'Require approvals',
            policy_scope: policy_scope,
            rules: [
              {
                type: 'scan_finding',
                branches: ['master'],
                scanners: %w[container_scanning],
                vulnerabilities_allowed: 0,
                severity_levels: %w[critical],
                vulnerability_states: %w[detected],
                vulnerability_attributes: {}
              },
              {
                type: 'license_finding',
                branches: ['master'],
                match_on_inclusion_license: true,
                license_types: %w[BSD MIT],
                license_states: %w[newly_detected detected]
              }
            ]
          )]
        }
      end
      # rubocop:enable RSpec/FactoriesInMigrationSpecs

      it 'creates multiple approval_policy_rules', :aggregate_failures do
        expect { perform_migration }.to change { security_policies.count }.by(1)
          .and change { approval_policy_rules.count }.by(2)
          .and change { approval_policy_rule_project_links.count }.by(2)

        approval_policy = security_policies.last
        approval_policy_rule_1 = approval_policy_rules.first
        approval_policy_rule_2 = approval_policy_rules.last
        security_policy_project_link_1 = approval_policy_rule_project_links.first
        security_policy_project_link_2 = approval_policy_rule_project_links.last

        expect(approval_policy_rule_1).to have_attributes(
          security_policy_id: approval_policy.id,
          type: 0,
          rule_index: 0,
          content: {
            'branches' => ['master'],
            'scanners' => ['container_scanning'],
            'severity_levels' => ['critical'],
            'vulnerabilities_allowed' => 0,
            'vulnerability_attributes' => {},
            'vulnerability_states' => ['detected']
          }
        )

        expect(approval_policy_rule_2).to have_attributes(
          security_policy_id: approval_policy.id,
          type: 1,
          rule_index: 1,
          content: {
            'branches' => ['master'],
            'license_states' => %w[newly_detected detected],
            'license_types' => %w[BSD MIT],
            'match_on_inclusion_license' => true
          }
        )

        expect(security_policy_project_link_1).to have_attributes(
          approval_policy_rule_id: approval_policy_rule_1.id,
          project_id: project.id
        )

        expect(security_policy_project_link_2).to have_attributes(
          approval_policy_rule_id: approval_policy_rule_2.id,
          project_id: project.id
        )
      end
    end

    it 'creates approval policies', :aggregate_failures do
      expect { perform_migration }.to change { security_policies.count }.by(1)
        .and change { approval_policy_rules.count }.by(1)
        .and change { security_policy_project_links.count }.by(1)
        .and change { approval_policy_rule_project_links.count }.by(1)

      approval_policy = security_policies.last
      approval_policy_rule = approval_policy_rules.last
      approval_policy_project_link = security_policy_project_links.last
      security_policy_project_link = approval_policy_rule_project_links.last

      expect(approval_policy).to have_attributes(
        type: 0,
        policy_index: 0,
        name: 'Require approvals',
        description: 'This policy considers only container scanning and critical severities',
        enabled: true,
        metadata: {},
        scope: {},
        content: {
          'actions' => [
            {
              'approvals_required' => 1,
              'type' => 'require_approval',
              'user_approvers' => ['admin']
            }
          ],
          'approval_settings' => {},
          'fallback_behavior' => {},
          'policy_tuning' => {}
        }
      )

      expect(approval_policy_rule).to have_attributes(
        security_policy_id: approval_policy.id,
        type: 0,
        rule_index: 0,
        content: {
          'branches' => ['master'],
          'scanners' => ['container_scanning'],
          'severity_levels' => ['critical'],
          'vulnerabilities_allowed' => 0,
          'vulnerability_attributes' => {},
          'vulnerability_states' => ['detected']
        }
      )

      expect(approval_policy_project_link).to have_attributes(
        security_policy_id: approval_policy.id,
        project_id: project.id
      )

      expect(security_policy_project_link).to have_attributes(
        approval_policy_rule_id: approval_policy_rule.id,
        project_id: project.id
      )
    end
  end

  context 'with pipeline_execution_policies' do
    let(:policies) { { pipeline_execution_policy: [pipeline_execution_policy] } }

    it 'creates pipeline execution policies', :aggregate_failures do
      expect { perform_migration }.to change { security_policies.count }.by(1)
        .and not_change { approval_policy_rules.count }
        .and change { security_policy_project_links.count }.by(1)
        .and not_change { approval_policy_rule_project_links.count }

      pipeline_execution_policy = security_policies.last

      expect(pipeline_execution_policy).to have_attributes(
        type: 2,
        policy_index: 0,
        name: 'Run compliance pipeline',
        description: 'This policy enforces execution of custom CI in the pipeline',
        enabled: true,
        metadata: {},
        scope: {},
        content: {
          'content' => {
            'include' => [
              {
                'file' => 'compliance-pipeline-ci.yml',
                'project' => 'compliance-project'
              }
            ]
          },
          'pipeline_config_strategy' => 'inject_ci',
          'suffix' => nil
        }
      )
    end
  end

  context 'with vulnerability_management_policies' do
    let(:policies) { { vulnerability_management_policy: [vulnerability_management_policy] } }

    it 'creates vulnerability_management_policy_rules', :aggregate_failures do
      expect { perform_migration }.to change { security_policies.count }.by(1)
        .and change { vulnerability_management_policy_rules.count }.by(1)
        .and change { security_policy_project_links.count }.by(1)
        .and not_change { approval_policy_rule_project_links.count }

      vulnerability_management_policy = security_policies.last
      vulnerability_management_policy_rule = vulnerability_management_policy_rules.last

      expect(vulnerability_management_policy).to have_attributes(
        type: 3,
        policy_index: 0,
        name: 'Manage vulnerabilities',
        description: 'This policy enforces resolving of no longer detected low SAST vulnerabilities',
        enabled: true,
        metadata: {},
        scope: {},
        content: {
          'actions' => [
            {
              'type' => 'auto_resolve'
            }
          ]
        }
      )

      expect(vulnerability_management_policy_rule).to have_attributes(
        security_policy_id: vulnerability_management_policy.id,
        type: 0,
        rule_index: 0,
        content: {
          'scanners' => [
            'sast'
          ],
          'severity_levels' => [
            'low'
          ]
        }
      )
    end
  end

  context 'with group level policies' do
    let!(:security_policy_config) do
      security_orchestration_policy_configurations.create!(
        security_policy_management_project_id: policy_project.id,
        namespace_id: group_namespace.id
      )
    end

    let!(:sub_group_namespace) do
      namespaces.create!(
        organization_id: organization.id,
        name: 'gitlab-com',
        path: 'gitlab-com',
        type: 'Group',
        parent_id: group_namespace.id
      ).tap { |namespace| namespace.update!(traversal_ids: [namespace.id]) }
    end

    let!(:project_2) { create_project('project 2', group_namespace) }
    let!(:project_in_sub_group) { create_project('project in subgroup', sub_group_namespace) }

    let(:policies) do
      {
        vulnerability_management_policy: [vulnerability_management_policy],
        pipeline_execution_policy: [pipeline_execution_policy],
        approval_policy: [approval_policy],
        scan_execution_policy: [scan_execution_policy]
      }
    end

    it 'creates records for every project records', :aggregate_failures do
      expect { perform_migration }.to change { security_policies.count }.by(4) # 1 per policy
        .and change { vulnerability_management_policy_rules.count }.by(1)
        .and change { approval_policy_rules.count }.by(1)
        .and change { scan_execution_policy_rules.count }.by(1)
        .and change { security_policy_project_links.count }.by(16) # Created for all policies per project
        .and change { approval_policy_rule_project_links.count }.by(4) # Created for approval policy per project
    end

    context 'when policy is scoped to project' do
      let(:policy_scope) do
        {
          projects: {
            including: [
              { id: project_2.id }
            ]
          }
        }
      end

      let(:policies) { { approval_policy: [approval_policy] } }

      it 'creates links only for the project in scope', :aggregate_failures do
        expect { perform_migration }.to change { security_policies.count }.by(1) # 1 per policy
          .and change { approval_policy_rules.count }.by(1)
          .and change { security_policy_project_links.count }.by(1)
          .and change { approval_policy_rule_project_links.count }.by(1)

        approval_policy = security_policies.last
        approval_policy_rule = approval_policy_rules.last
        approval_policy_project_link = security_policy_project_links.last
        security_policy_project_link = approval_policy_rule_project_links.last

        expect(approval_policy_project_link).to have_attributes(
          security_policy_id: approval_policy.id,
          project_id: project_2.id
        )

        expect(security_policy_project_link).to have_attributes(
          approval_policy_rule_id: approval_policy_rule.id,
          project_id: project_2.id
        )
      end
    end

    context 'when policy is scoped to a group' do
      let(:policy_scope) do
        {
          groups: {
            including: [
              { id: sub_group_namespace.id }
            ]
          }
        }
      end

      let(:policies) { { approval_policy: [approval_policy] } }

      it 'creates links only for the project in group scope', :aggregate_failures do
        expect { perform_migration }.to change { security_policies.count }.by(1) # 1 per policy
          .and change { approval_policy_rules.count }.by(1)
          .and change { security_policy_project_links.count }.by(1)
          .and change { approval_policy_rule_project_links.count }.by(1)

        approval_policy = security_policies.last
        approval_policy_rule = approval_policy_rules.last
        approval_policy_project_link = security_policy_project_links.last
        security_policy_project_link = approval_policy_rule_project_links.last

        expect(approval_policy_project_link).to have_attributes(
          security_policy_id: approval_policy.id,
          project_id: project_in_sub_group.id
        )

        expect(security_policy_project_link).to have_attributes(
          approval_policy_rule_id: approval_policy_rule.id,
          project_id: project_in_sub_group.id
        )
      end
    end

    context 'when policy is unscoped to a group' do
      let(:policy_scope) do
        {
          groups: {
            excluding: [
              { id: sub_group_namespace.id }
            ]
          }
        }
      end

      let(:policies) { { approval_policy: [approval_policy] } }

      it 'creates links only for the project with excluding group scope', :aggregate_failures do
        expect { perform_migration }.to change { security_policies.count }.by(1) # 1 per policy
          .and change { approval_policy_rules.count }.by(1)
          .and change { security_policy_project_links.count }.by(3)
          .and change { approval_policy_rule_project_links.count }.by(3)

        approval_policy = security_policies.last
        approval_policy_rule = approval_policy_rules.last
        approval_policy_project_link = security_policy_project_links.last
        security_policy_project_link = approval_policy_rule_project_links.last

        expect(approval_policy_project_link).to have_attributes(
          security_policy_id: approval_policy.id,
          project_id: project_2.id
        )

        expect(security_policy_project_link).to have_attributes(
          approval_policy_rule_id: approval_policy_rule.id,
          project_id: project_2.id
        )
      end
    end

    # rubocop:disable RSpec/MultipleMemoizedHelpers -- We need extra helpers to define tables
    context 'when policy is scoped to compliance framework' do
      let!(:compliance_management_framework) do
        compliance_management_frameworks.create!(
          name: 'name',
          color: '#000000',
          description: 'description',
          namespace_id: group_namespace.id
        )
      end

      let!(:compliance_framework_project_setting) do
        compliance_framework_project_settings.create!(
          project_id: project_2.id,
          framework_id: compliance_management_framework.id
        )
      end

      let(:policy_scope) do
        {
          compliance_frameworks: [
            { id: compliance_management_framework.id }
          ]
        }
      end

      let(:policies) { { approval_policy: [approval_policy] } }

      it 'creates links only for the project in scope', :aggregate_failures do
        expect { perform_migration }.to change { security_policies.count }.by(1) # 1 per policy
          .and change { approval_policy_rules.count }.by(1)
          .and change { security_policy_project_links.count }.by(1)
          .and change { approval_policy_rule_project_links.count }.by(1)

        approval_policy = security_policies.last
        approval_policy_rule = approval_policy_rules.last
        approval_policy_project_link = security_policy_project_links.last
        security_policy_project_link = approval_policy_rule_project_links.last

        expect(approval_policy_project_link).to have_attributes(
          security_policy_id: approval_policy.id,
          project_id: project_2.id
        )

        expect(security_policy_project_link).to have_attributes(
          approval_policy_rule_id: approval_policy_rule.id,
          project_id: project_2.id
        )
      end
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers
  end

  context 'for invalid policies' do
    let(:invalid_policy) { { name: 'invalid', invalid: 'yes' } }
    let(:policies) do
      {
        vulnerability_management_policy: [vulnerability_management_policy],
        pipeline_execution_policy: [pipeline_execution_policy],
        approval_policy: [approval_policy, invalid_policy],
        scan_execution_policy: [scan_execution_policy]
      }
    end

    it 'does not create any records', :aggregate_failures do
      expect { perform_migration }.to not_change { security_policies.count }
        .and not_change { vulnerability_management_policy_rules.count }
        .and not_change { security_policy_project_links.count }
        .and not_change { approval_policy_rule_project_links.count }
    end
  end

  context 'when policies already exists in database' do
    let(:policies) do
      {
        vulnerability_management_policy: [vulnerability_management_policy],
        pipeline_execution_policy: [pipeline_execution_policy],
        approval_policy: [approval_policy],
        scan_execution_policy: [scan_execution_policy]
      }
    end

    before do
      create_policy(:approval_policy, approval_policy, 0)
      create_policy(:scan_execution_policy, scan_execution_policy, 0)
      create_policy(:pipeline_execution_policy, pipeline_execution_policy, 0)
    end

    context 'when some policies are persisted' do
      it 'creates missing records', :aggregate_failures do
        expect { perform_migration }.to change { security_policies.count }.by(1)
          .and change { vulnerability_management_policy_rules.count }.by(1)
          .and change { security_policy_project_links.count }.by(1)
          .and not_change { approval_policy_rules.count }
          .and not_change { scan_execution_policy_rules.count }
          .and not_change { approval_policy_rule_project_links.count }
      end
    end

    context 'when all policies are persisted' do
      before do
        create_policy(:vulnerability_management_policy, vulnerability_management_policy, 0)
      end

      it 'does not create any records', :aggregate_failures do
        expect { perform_migration }.to not_change { security_policies.count }
          .and not_change { vulnerability_management_policy_rules.count }
          .and not_change { security_policy_project_links.count }
          .and not_change { approval_policy_rule_project_links.count }
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
      path: name,
      archived: true
    )
  end

  def create_policy(policy_type, policy_hash, policy_index)
    security_policies.create!(
      {
        type: described_class::SecurityPolicy.types[policy_type],
        policy_index: policy_index,
        name: policy_hash[:name],
        description: policy_hash[:description],
        enabled: policy_hash[:enabled],
        metadata: policy_hash.fetch(:metadata, {}),
        scope: policy_hash.fetch(:policy_scope, {}),
        content: policy_hash.slice(*described_class::SecurityPolicy::POLICY_CONTENT_FIELDS[policy_type]),
        checksum: Digest::SHA256.hexdigest(policy_hash.to_json),
        security_orchestration_policy_configuration_id: security_policy_config.id,
        security_policy_management_project_id: security_policy_config.security_policy_management_project_id
      }
    )
  end
end
