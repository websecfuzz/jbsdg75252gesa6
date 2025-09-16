# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::BackfillEpicsWorkItemParentLinkId, feature_category: :team_planning do
  let(:parent_links) { table(:work_item_parent_links) }
  let(:epics) { table(:epics) }
  let(:issues) { table(:issues) }

  let(:author) { table(:users).create!(username: 'tester', projects_limit: 100, organization_id: organization.id) }
  let(:organization) { table(:organizations).create!(name: 'organization', path: 'organization') }
  let(:namespace) do
    table(:namespaces).create!(name: 'my test group1', path: 'my-test-group1', organization_id: organization.id)
  end

  let(:child_epic_new_link) do
    create_epic_with_work_item(title: 'Child Epic 2', iid: 3, parent_id: parent_epic.id)
  end

  let(:parent_epic) { create_epic_with_work_item(title: 'Parent Epic', iid: 1) }
  let!(:child_epic_existing_link) do
    child_epic = create_epic_with_work_item(title: 'Child Epic 1', iid: 2, parent_id: parent_epic.id)
    parent_links.create!(
      work_item_id: child_epic.issue_id,
      work_item_parent_id: parent_epic.issue_id,
      relative_position: 0,
      namespace_id: namespace.id,
      created_at: now,
      updated_at: now
    )
    child_epic
  end

  let(:epic_type_id) { table(:work_item_types).find_by(name: 'Epic').id }

  let(:now) { Time.current }

  subject(:migration) do
    described_class.new(
      start_id: epics.minimum(:id),
      end_id: epics.maximum(:id),
      batch_table: :epics,
      batch_column: :id,
      sub_batch_size: 1,
      pause_ms: 0,
      connection: ApplicationRecord.connection
    )
  end

  it 'backfills the FK for an existing parent link' do
    expect do
      migration.perform
    end.to change { child_epic_existing_link.reload.work_item_parent_link_id }.from(nil).to(parent_links.first.id)
  end

  it 'creates a new parent link with the child epic\'s relative_position and backfills the FK' do
    # Verify that the parent link does not exist before the migration
    expect(
      parent_links.find_by(
        work_item_id: child_epic_new_link.issue_id,
        work_item_parent_id: parent_epic.issue_id
      )
    ).to be_nil

    # Perform the migration
    expect do
      migration.perform
    end.to change { parent_links.count }.by(1)

    # Verify that the parent link exists after the migration
    new_link = parent_links.find_by(
      work_item_id: child_epic_new_link.issue_id,
      work_item_parent_id: parent_epic.issue_id
    )

    expect(new_link).not_to be_nil
    expect(child_epic_new_link.reload.work_item_parent_link_id).to eq(new_link.id)

    # Verify the relative_position matches the child epic's relative_position
    expect(new_link.relative_position).to eq(issues.find(child_epic_new_link.issue_id).relative_position)
  end

  it 'does nothing when no parent-child relationships exist' do
    epics.update_all(parent_id: nil)

    # Capture the initial state of work_item_parent_link_id before the migration
    initial_epic_parent_link_ids = epics.pluck(:id, :work_item_parent_link_id).to_h

    expect { migration.perform }.not_to change { parent_links.count }

    # Verify that work_item_parent_link_id values remain unchanged
    final_epic_parent_link_ids = epics.pluck(:id, :work_item_parent_link_id).to_h
    expect(final_epic_parent_link_ids).to eq(initial_epic_parent_link_ids)
  end

  it 'creates a new parent link and backfills the FK' do
    # Verify that the parent link does not exist before the migration
    expect(
      parent_links.find_by(
        work_item_id: child_epic_new_link.issue_id,
        work_item_parent_id: parent_epic.issue_id
      )
    ).to be_nil

    expect do
      migration.perform
    end.to change { parent_links.count }.by(1)

    # Verify that the parent link exists after the migration
    new_link = parent_links.find_by(
      work_item_id: child_epic_new_link.issue_id,
      work_item_parent_id: parent_epic.issue_id
    )

    expect(new_link).not_to be_nil
    expect(child_epic_new_link.reload.work_item_parent_link_id).to eq(new_link.id)
  end

  def create_epic_with_work_item(iid:, title:, parent_id: nil)
    work_item = issues.create!(
      iid: iid,
      author_id: author.id,
      work_item_type_id: epic_type_id,
      namespace_id: namespace.id,
      lock_version: 1,
      title: title
    )

    epics.create!(
      iid: iid,
      title: title,
      title_html: title,
      group_id: namespace.id,
      author_id: author.id,
      issue_id: work_item.id,
      parent_id: parent_id
    )
  end
end
