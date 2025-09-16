# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::ResyncApprovalPolicies, feature_category: :security_policy_management do
  describe '#perform' do
    let(:security_policies) { table(:security_policies) }
    let(:security_orchestration_policy_configurations) { table(:security_orchestration_policy_configurations) }
    let(:projects) { table(:projects) }
    let(:namespaces) { table(:namespaces) }

    let(:organization) { table(:organizations).create!(name: 'organization', path: 'organization') }
    let(:namespace) { namespaces.create!(name: 'namespace', path: 'namespace', organization_id: organization.id) }
    let(:project) { create_project('project', namespace) }
    let(:another_project) { create_project('another_project', namespace) }
    let(:policy_project) { create_project('policy_project', namespace) }

    let!(:policy_configuration_1) do
      security_orchestration_policy_configurations.create!(
        project_id: project.id,
        security_policy_management_project_id: policy_project.id
      )
    end

    let!(:policy_configuration_2) do
      security_orchestration_policy_configurations.create!(
        namespace_id: namespace.id,
        security_policy_management_project_id: policy_project.id
      )
    end

    let!(:policy_configuration_3) do
      security_orchestration_policy_configurations.create!(
        project_id: another_project.id,
        security_policy_management_project_id: policy_project.id
      )
    end

    let!(:disabled_policy_without_scope_1) do
      create_policy(policy_configuration_1, 0, 0, 'Policy 1', false, {})
    end

    let!(:disabled_policy_with_scope) do
      create_policy(policy_configuration_1, 0, 1, 'Policy 2', false, { 'foo' => 'bar' })
    end

    let!(:policy_with_scope) do
      create_policy(policy_configuration_2, 0, 0, 'Policy 2', true, { 'foo' => 'bar' })
    end

    let!(:disabled_policy_without_scope_2) do
      create_policy(policy_configuration_2, 0, 1, 'Policy 3', false, {})
    end

    let!(:invalid_type_policy) do
      create_policy(policy_configuration_3, 1, 0, 'Policy 4', true, {})
    end

    subject(:migration) do
      described_class.new(
        start_id: disabled_policy_without_scope_1.id,
        end_id: invalid_type_policy.id,
        batch_table: :security_policies,
        batch_column: :id,
        sub_batch_size: 2,
        pause_ms: 0,
        connection: ApplicationRecord.connection
      )
    end

    it 'enqueues Security::PersistSecurityPoliciesWorker for matching policies with delay' do
      expect(Security::PersistSecurityPoliciesWorker)
        .to receive(:perform_in).with(0, policy_configuration_1.id)
      expect(Security::PersistSecurityPoliciesWorker)
        .to receive(:perform_in).with(10, policy_configuration_2.id)
      expect(Security::PersistSecurityPoliciesWorker)
        .not_to receive(:perform_in).with(anything, policy_configuration_3.id)

      migration.perform
    end

    context 'when no policies match criteria' do
      before do
        security_policies.update_all(type: 1, enabled: true, scope: '{}')
      end

      it 'does not enqueue any workers' do
        expect(Security::PersistSecurityPoliciesWorker).not_to receive(:perform_in)

        migration.perform
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

    projects.create!(
      organization_id: group.organization_id,
      namespace_id: group.id,
      project_namespace_id: project_namespace.id,
      name: name,
      path: name,
      archived: true
    )
  end

  def create_policy(policy_configuration, policy_type, policy_index, name, enabled, policy_scope)
    security_policies.create!(
      {
        type: policy_type,
        policy_index: policy_index,
        name: name,
        description: 'Test Description',
        enabled: enabled,
        metadata: {},
        scope: policy_scope,
        content: {},
        checksum: Digest::SHA256.hexdigest({}.to_json),
        security_orchestration_policy_configuration_id: policy_configuration.id,
        security_policy_management_project_id: policy_configuration.security_policy_management_project_id
      }
    )
  end
end
