# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::SyncUnlinkedSecurityPolicyProjectLinks, feature_category: :security_policy_management do
  let(:security_orchestration_policy_configurations) { table(:security_orchestration_policy_configurations) }
  let(:namespaces) { table(:namespaces) }
  let(:security_policies) { table(:security_policies) }
  let(:approval_policy_rules) { table(:approval_policy_rules) }
  let(:security_policy_project_links) { table(:security_policy_project_links) }
  let(:approval_policy_rule_project_links) { table(:approval_policy_rule_project_links) }
  let(:compliance_management_frameworks) { table(:compliance_management_frameworks) }
  let(:compliance_framework_project_settings) { table(:project_compliance_framework_settings) }

  let(:args) do
    min, max = security_policies.pick('MIN(id)', 'MAX(id)')

    {
      start_id: min,
      end_id: max,
      batch_table: 'security_policies',
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

  let!(:project) { create_project('project', group_namespace) }
  let!(:policy_project) { create_project('policy_project', group_namespace) }

  let!(:security_policy_config) do
    security_orchestration_policy_configurations.create!(
      security_policy_management_project_id: policy_project.id,
      namespace_id: group_namespace.id
    )
  end

  subject(:perform_migration) { described_class.new(**args).perform }

  shared_examples_for 'creates only policy project links' do
    it 'creates only policy project links' do
      perform_migration

      expect(security_policy_project_links.where(security_policy_id: policy.id, project_id: project.id)).to exist
      expect(approval_policy_rule_project_links.count).to eq(0)
    end
  end

  describe '#perform' do
    let(:policy_hash) do
      {
        name: 'Test Policy',
        description: 'Test Description',
        enabled: true,
        metadata: {},
        policy_scope: policy_scope
      }
    end

    context 'with project level config' do
      let!(:security_policy_config) do
        security_orchestration_policy_configurations.create!(
          security_policy_management_project_id: policy_project.id,
          project_id: project.id
        )
      end

      let!(:policy) { create_policy(:scan_execution_policy, policy_hash, 0) }

      it_behaves_like 'creates only policy project links'
    end

    context 'with approval_policy_rules' do
      let!(:project_2) { create_project('project_2', group_namespace) }
      let!(:policy) { create_policy(:approval_policy, policy_hash, 0) }
      let!(:approval_policy_rule_1) do
        approval_policy_rules.create!(
          security_policy_id: policy.id,
          type: 0,
          rule_index: 0,
          security_policy_management_project_id: policy_project.id
        )
      end

      let!(:approval_policy_rule_2) do
        approval_policy_rules.create!(
          security_policy_id: policy.id,
          type: 0,
          rule_index: 1,
          security_policy_management_project_id: policy_project.id
        )
      end

      before do
        security_policy_project_links.create!(security_policy_id: policy.id, project_id: policy_project.id)
        approval_policy_rule_project_links.create!(approval_policy_rule_id: approval_policy_rule_1.id,
          project_id: policy_project.id)
        approval_policy_rule_project_links.create!(approval_policy_rule_id: approval_policy_rule_2.id,
          project_id: policy_project.id)
      end

      it 'creates policy and rule project links' do
        expect { perform_migration }.to change { security_policy_project_links.count }.by(2)
          .and change { approval_policy_rule_project_links.count }.by(4)

        expect(security_policy_project_links.where(security_policy_id: policy.id, project_id: project.id)).to exist
        expect(security_policy_project_links.where(security_policy_id: policy.id, project_id: project_2.id)).to exist

        expect(approval_policy_rule_project_links.where(approval_policy_rule_id: approval_policy_rule_1.id,
          project_id: project.id)).to exist
        expect(approval_policy_rule_project_links.where(approval_policy_rule_id: approval_policy_rule_1.id,
          project_id: project_2.id)).to exist

        expect(approval_policy_rule_project_links.where(approval_policy_rule_id: approval_policy_rule_2.id,
          project_id: project.id)).to exist
        expect(approval_policy_rule_project_links.where(approval_policy_rule_id: approval_policy_rule_2.id,
          project_id: project_2.id)).to exist
      end

      context 'when links already exist' do
        before do
          security_policy_project_links.create!(security_policy_id: policy.id, project_id: project.id)
          approval_policy_rule_project_links.create!(approval_policy_rule_id: approval_policy_rule_1.id,
            project_id: project.id)
          approval_policy_rule_project_links.create!(approval_policy_rule_id: approval_policy_rule_2.id,
            project_id: project.id)
        end

        it 'creates only the missing links' do
          expect { perform_migration }.to change { security_policy_project_links.count }.by(1)
          .and change { approval_policy_rule_project_links.count }.by(2)

          expect(security_policy_project_links.where(security_policy_id: policy.id, project_id: project.id)).to exist

          expect(approval_policy_rule_project_links.where(approval_policy_rule_id: approval_policy_rule_1.id,
            project_id: project_2.id)).to exist
          expect(approval_policy_rule_project_links.where(approval_policy_rule_id: approval_policy_rule_2.id,
            project_id: project_2.id)).to exist
        end
      end
    end

    context 'without approval_policy_rules' do
      let!(:policy) { create_policy(:approval_policy, policy_hash, 0) }

      it_behaves_like 'creates only policy project links'
    end

    context 'with policy scopes' do
      let!(:another_project) { create_project('another_project', group_namespace) }
      let!(:policy) { create_policy(:scan_execution_policy, policy_hash, 0) }

      let!(:sub_group_namespace) do
        namespaces.create!(
          organization_id: organization.id,
          name: 'gitlab-com',
          path: 'gitlab-com',
          type: 'Group',
          parent_id: group_namespace.id
        ).tap { |namespace| namespace.update!(traversal_ids: [group_namespace.id, namespace.id]) }
      end

      let!(:project_in_sub_group) { create_project('project in subgroup', sub_group_namespace) }

      context 'with project scope' do
        let(:policy_scope) do
          {
            projects: {
              including: [{ id: project.id }],
              excluding: [{ id: another_project.id }]
            }
          }
        end

        it 'creates links only for included projects' do
          perform_migration

          expect(security_policy_project_links.where(security_policy_id: policy.id,
            project_id: project.id)).to exist
          expect(security_policy_project_links.where(security_policy_id: policy.id,
            project_id: another_project.id)).not_to exist
        end
      end

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
            project_id: project.id,
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

        it 'creates links only for the project in scope', :aggregate_failures do
          perform_migration

          expect(security_policy_project_links.where(security_policy_id: policy.id,
            project_id: project.id)).to exist
          expect(security_policy_project_links.where(security_policy_id: policy.id,
            project_id: another_project.id)).not_to exist
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

        it 'creates links only for the project in scope', :aggregate_failures do
          perform_migration

          expect(security_policy_project_links.where(security_policy_id: policy.id,
            project_id: project_in_sub_group.id)).to exist
          expect(security_policy_project_links.where(security_policy_id: policy.id,
            project_id: another_project.id)).not_to exist
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

        it 'creates links only for the project in scope', :aggregate_failures do
          perform_migration

          expect(security_policy_project_links.where(security_policy_id: policy.id,
            project_id: project_in_sub_group.id)).not_to exist
          expect(security_policy_project_links.where(security_policy_id: policy.id,
            project_id: another_project.id)).to exist
        end
      end

      context 'with no projects in the scope' do
        let!(:compliance_management_framework) do
          compliance_management_frameworks.create!(
            name: 'new framework',
            color: '#000000',
            description: 'description',
            namespace_id: group_namespace.id
          )
        end

        let(:policy_scope) do
          {
            compliance_frameworks: [
              { id: compliance_management_framework.id }
            ]
          }
        end

        it 'does not create new links' do
          expect { perform_migration }.not_to change { security_policy_project_links.count }
        end
      end
    end

    context 'when policy is disabled' do
      let!(:policy) { create_policy(:scan_execution_policy, policy_hash.merge(enabled: false), 0) }

      it 'does not create any links' do
        expect { perform_migration }.not_to change { security_policy_project_links.count }
      end
    end
  end

  def create_project(name, group)
    project_namespace = namespaces.create!(
      name: name,
      path: name,
      type: 'Project',
      parent_id: group.id,
      organization_id: group.organization_id
    ).tap { |namespace| namespace.update!(traversal_ids: [*group.traversal_ids, namespace.id]) }

    table(:projects).create!(
      organization_id: group.organization_id,
      namespace_id: group.id,
      project_namespace_id: project_namespace.id,
      name: name,
      path: name
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
        content: policy_hash.fetch(:content, {}),
        checksum: Digest::SHA256.hexdigest(policy_hash.to_json),
        security_orchestration_policy_configuration_id: security_policy_config.id,
        security_policy_management_project_id: policy_project.id
      }
    )
  end
end
