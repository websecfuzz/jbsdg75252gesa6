# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::BackfillComplianceViolationNullTargetProjectIds,
  feature_category: :compliance_management do
  let(:connection) { ApplicationRecord.connection }

  let(:organizations) { table(:organizations) }
  let(:namespaces) { table(:namespaces) }
  let(:projects) { table(:projects) }
  let(:users) { table(:users) }

  let(:merge_requests) { table(:merge_requests) }
  let(:violating_user) do
    users.create!(username: 'john_doe', email: 'johndoe@gitlab.com', projects_limit: 2,
      organization_id: organization.id)
  end

  let!(:organization) { organizations.create!(name: 'organization', path: 'organization') }
  let!(:namespace) do
    namespaces
      .create!(name: 'root-group', path: 'root', type: 'Group', organization_id: organization.id)
      .tap do |new_group|
        new_group.update!(traversal_ids: [new_group.id])
      end
  end

  let!(:group_1) do
    namespaces.create!(name: 'random-group', path: 'random', type: 'Group', organization_id: organization.id)
  end

  let!(:group_2) do
    namespaces.create!(name: 'random-group-2', path: 'random-2', type: 'Group', organization_id: organization.id)
  end

  let!(:nested_group) do
    namespaces
      .create!(name: 'nested-group', path: 'root/nested_group', type: 'Group', organization_id: organization.id)
      .tap do |new_group|
        new_group.update!(traversal_ids: [namespace.id, new_group.id])
      end
  end

  let!(:project_1) do
    projects.create!(
      organization_id: organization.id,
      namespace_id: nested_group.id,
      project_namespace_id: nested_group.id,
      name: 'test project',
      path: 'test-project'
    )
  end

  let!(:project_2) do
    projects.create!(
      organization_id: organization.id,
      namespace_id: group_1.id,
      project_namespace_id: group_1.id,
      name: 'test project-2',
      path: 'test-project-2'
    )
  end

  let!(:project_3) do
    projects.create!(
      organization_id: organization.id,
      namespace_id: group_2.id,
      project_namespace_id: group_2.id,
      name: 'test project-3',
      path: 'test-project-3'
    )
  end

  let!(:merge_request_1) do
    table(:merge_requests).create!(target_project_id: project_1.id, target_branch: 'main', source_branch: 'not-main')
  end

  let!(:merge_request_2) do
    table(:merge_requests).create!(target_project_id: project_2.id, target_branch: 'main', source_branch: 'not-main')
  end

  let!(:merge_request_3) do
    table(:merge_requests).create!(target_project_id: project_3.id, target_branch: 'main', source_branch: 'not-main')
  end

  let(:merge_requests_compliance_violations) { table(:merge_requests_compliance_violations) }
  let!(:mr_compliance_violation_1) do
    merge_requests_compliance_violations.create!(title: 'Has Target Project', merge_request_id: merge_request_1.id,
      target_project_id: project_1.id, violating_user_id: violating_user.id, reason: 1)
  end

  let!(:mr_compliance_violation_2) do
    merge_requests_compliance_violations.create!(title: 'Wrong Target Project', target_project_id: project_2.id,
      merge_request_id: merge_request_3.id, violating_user_id: violating_user.id, reason: 2)
  end

  describe '#perform' do
    it 'runs without error' do
      migration = described_class.new(
        start_id: mr_compliance_violation_1.id,
        end_id: mr_compliance_violation_2.id,
        batch_table: :merge_requests_compliance_violations,
        batch_column: :id,
        sub_batch_size: 10,
        pause_ms: 0,
        connection: connection
      )
      expect { migration.perform }.to not_change {
        mr_compliance_violation_2.reload.target_project_id
      }.from(project_2.id)
      expect(merge_requests_compliance_violations.find_by_id(mr_compliance_violation_1.id).target_project_id)
        .to eq(merge_request_1.target_project_id)
    end
  end
end
