# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::BackfillPipelineExecutionPoliciesMetadata, feature_category: :security_policy_management do
  let(:security_orchestration_policy_configurations) { table(:security_orchestration_policy_configurations) }
  let(:security_policies) { table(:security_policies) }
  let(:security_pipeline_execution_policy_config_links) { table(:security_pipeline_execution_policy_config_links) }
  let(:organizations) { table(:organizations) }
  let(:projects) { table(:projects) }
  let(:namespaces) { table(:namespaces) }
  let(:user) do
    table(:users).create!(email: 'john@doe', username: 'john_doe', projects_limit: 10, organization_id: organization.id)
  end

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

  let!(:policy_2) do
    security_policies.create!(
      name: 'PEP 2',
      security_orchestration_policy_configuration_id: configuration.id,
      policy_index: 1,
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

  shared_examples_for 'does not enqueue the workers' do
    it 'does not enqueue the worker' do
      expect(Security::SyncPipelineExecutionPolicyMetadataWorker).not_to receive(:perform_in)

      perform_migration
    end
  end

  context 'with user and config link' do
    before do
      create_spp_merge_request!
      create_policy_config_links!
    end

    it 'enqueues the workers', :aggregate_failures do
      expect(Security::SyncPipelineExecutionPolicyMetadataWorker).to receive(:perform_in)
        .with(0, config_project.id, user.id, pipeline_execution_policy_content.deep_stringify_keys, [policy.id])
      expect(Security::SyncPipelineExecutionPolicyMetadataWorker).to receive(:perform_in)
        .with(10, config_project.id, user.id, pipeline_execution_policy_content.deep_stringify_keys, [policy_2.id])

      perform_migration
    end
  end

  context 'with config link but no user' do
    before do
      create_policy_config_links!
    end

    it_behaves_like 'does not enqueue the workers'
  end

  context 'with user but no config link' do
    before do
      create_spp_merge_request!
    end

    it_behaves_like 'does not enqueue the workers'
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

    it_behaves_like 'does not enqueue the workers'
  end

  private

  def create_policy_config_links!
    security_pipeline_execution_policy_config_links.create!(
      project_id: config_project.id,
      security_policy_id: policy.id)
    security_pipeline_execution_policy_config_links.create!(
      project_id: config_project.id,
      security_policy_id: policy_2.id)
  end

  def create_spp_merge_request!
    table(:merge_requests).create!(target_project_id: policy_project.id, target_branch: 'main',
      source_branch: 'update-policy-123', state_id: 3, author_id: user.id).tap do |merge_request|
      table(:merge_request_metrics).create!(
        target_project_id: policy_project.id, merge_request_id: merge_request.id, merged_at: 1.day.ago
      )
    end
  end
end
