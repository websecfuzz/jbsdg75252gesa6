# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::BackfillPipelineExecutionPoliciesConfigLinks, feature_category: :security_policy_management do
  let(:security_orchestration_policy_configurations) { table(:security_orchestration_policy_configurations) }
  let(:security_policies) { table(:security_policies) }
  let(:security_pipeline_execution_policy_config_links) { table(:security_pipeline_execution_policy_config_links) }
  let(:organizations) { table(:organizations) }
  let(:projects) { table(:projects) }
  let(:routes) { table(:routes) }
  let(:namespaces) { table(:namespaces) }
  let(:organization) { organizations.create!(name: 'organization', path: 'organization') }
  let(:namespace) { namespaces.create!(name: 'Test', path: 'test', organization_id: organization.id) }
  let(:project_namespace) do
    namespaces.create!(name: 'Project1', path: 'project_1', type: 'Project', organization_id: organization.id)
  end

  let(:spp_project_namespace) do
    namespaces.create!(name: 'Project2', path: 'spp', type: 'Project', organization_id: organization.id)
  end

  let(:config_project_namespace) do
    namespaces.create!(name: 'PEP config', path: 'pep-config', type: 'Project', organization_id: organization.id)
  end

  let(:project) do
    projects.create!(
      name: 'project_1',
      path: 'project_1',
      namespace_id: namespace.id,
      project_namespace_id: project_namespace.id,
      organization_id: organization.id
    )
  end

  let(:policy_project) do
    projects.create!(
      name: 'SPP',
      path: 'spp',
      namespace_id: namespace.id,
      project_namespace_id: spp_project_namespace.id,
      organization_id: organization.id
    )
  end

  let!(:config_project) do
    projects.create!(
      name: 'PEP config',
      path: 'pep-config',
      namespace_id: namespace.id,
      project_namespace_id: config_project_namespace.id,
      organization_id: organization.id
    )
  end

  let!(:config_project_route) do
    routes.create!(path: 'pep-config', source_id: config_project.id, namespace_id: namespace.id,
      source_type: 'Project')
  end

  let(:configuration) do
    security_orchestration_policy_configurations.create!(
      security_policy_management_project_id: policy_project.id,
      project_id: project.id
    )
  end

  let(:pipeline_execution_policy_content) do
    { include: [{ project: 'pep-config', file: 'compliance-pipeline.yml' }] }
  end

  let!(:policy) do
    security_policies.create!(
      name: 'PEP',
      security_orchestration_policy_configuration_id: configuration.id,
      policy_index: 0,
      checksum: '0' * 64,
      security_policy_management_project_id: policy_project.id,
      type: described_class::SecurityPolicy.types[:pipeline_execution_policy],
      content: {
        content: pipeline_execution_policy_content,
        pipeline_config_strategy: 'inject_ci'
      }
    )
  end

  let(:args) do
    min, max = security_policies.pick('MIN(id)', 'MAX(id)')
    {
      start_id: min,
      end_id: max,
      batch_table: 'security_policies',
      batch_column: 'id',
      sub_batch_size: 1000,
      pause_ms: 0,
      connection: ApplicationRecord.connection
    }
  end

  subject(:perform_migration) { described_class.new(**args).perform }

  shared_examples_for 'creates the link' do
    it 'creates the link', :aggregate_failures do
      expect { perform_migration }.to change { security_pipeline_execution_policy_config_links.count }.from(0).to(1)

      link = security_pipeline_execution_policy_config_links.first
      expect(link.project_id).to eq(config_project.id)
      expect(link.security_policy_id).to eq(policy.id)
    end
  end

  it_behaves_like 'creates the link'

  context 'when the links already exist' do
    let!(:existing_link) do
      security_pipeline_execution_policy_config_links.create!(
        project_id: config_project.id,
        security_policy_id: policy.id)
    end

    it 'does not change the existing links' do
      expect { perform_migration }.not_to change { existing_link.reload }
    end
  end

  context 'when PEP project is referenced as case-insensitive' do
    let(:pipeline_execution_policy_content) do
      { include: [{ project: 'PEP-CONFIG', file: 'compliance-pipeline.yml' }] }
    end

    it_behaves_like 'creates the link'
  end

  context 'when the referenced PEP project does not exist' do
    let(:pipeline_execution_policy_content) do
      { include: [{ project: 'pep-project-does-not-exist', file: 'compliance-pipeline.yml' }] }
    end

    it 'does not create the link' do
      expect { perform_migration }.not_to change { security_pipeline_execution_policy_config_links.count }
    end
  end

  context 'when policy is not a pipeline execution policy' do
    let!(:policy) do
      security_policies.create!(
        name: 'Approval policy',
        security_orchestration_policy_configuration_id: configuration.id,
        policy_index: 0,
        checksum: '0' * 64,
        security_policy_management_project_id: policy_project.id,
        type: described_class::SecurityPolicy.types[:approval_policy],
        content: {}
      )
    end

    it 'does not create the link' do
      expect { perform_migration }.not_to change { security_pipeline_execution_policy_config_links.count }
    end
  end
end
