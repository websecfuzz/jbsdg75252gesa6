# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::BackfillEpicIssuesWorkItemParentLinkId, feature_category: :team_planning do
  let(:namespaces) { table(:namespaces) }
  let(:issues) { table(:issues) }
  let(:epics) { table(:epics) }
  let(:epic_issues) { table(:epic_issues) }
  let(:work_item_parent_links) { table(:work_item_parent_links) }
  let(:work_item_types) { table(:work_item_types) }
  let(:organizations) { table(:organizations) }
  let!(:author) { table(:users).create!(username: 'tester', projects_limit: 100, organization_id: organization.id) }

  let!(:organization) { organizations.create!(name: 'test-org', path: 'test-org') }

  let(:issue_type) { work_item_types.find_by!(base_type: 0) } # Issue type
  let(:epic_type) { work_item_types.find_by!(base_type: 7) } # Epic type

  let!(:epic_work_item) do
    issues.create!(
      title: 'Epic Work Item',
      description: 'Epic as work item',
      namespace_id: group.id,
      work_item_type_id: epic_type.id,
      author_id: author.id
    )
  end

  let!(:issue_work_item) do
    issues.create!(
      title: 'Child Issue',
      description: 'Child issue',
      namespace_id: group.id,
      work_item_type_id: issue_type.id,
      author_id: author.id
    )
  end

  let!(:epic) do
    epics.create!(
      title: 'Test Epic',
      title_html: 'test',
      description: 'Test epic description',
      group_id: group.id,
      issue_id: epic_work_item.id,
      author_id: author.id,
      iid: 1
    )
  end

  let!(:group) do
    namespaces.create!(
      name: 'test-group',
      path: 'test-group',
      type: 'Group',
      organization_id: organization.id
    ).tap do |new_group|
      new_group.update!(traversal_ids: [new_group.id])
    end
  end

  subject(:migration) do
    described_class.new(
      start_id: epic_issues.minimum(:id),
      end_id: epic_issues.maximum(:id),
      batch_table: :epic_issues,
      batch_column: :id,
      sub_batch_size: 1,
      pause_ms: 0,
      connection: ApplicationRecord.connection
    )
  end

  describe '#perform' do
    context 'when EpicIssue has nil work_item_parent_link_id but a ParentLink exists' do
      let!(:work_item_parent_link) do
        work_item_parent_links.create!(
          work_item_id: issue_work_item.id,
          work_item_parent_id: epic_work_item.id,
          namespace_id: group.id
        )
      end

      let!(:epic_issue) do
        epic_issues.create!(
          epic_id: epic.id,
          issue_id: issue_work_item.id,
          namespace_id: group.id,
          work_item_parent_link_id: nil
        )
      end

      it 'backfills the work_item_parent_link_id' do
        expect do
          migration.perform
        end.to change { epic_issue.reload.work_item_parent_link_id }
          .from(nil)
          .to(work_item_parent_link.id)
      end
    end

    context 'when EpicIssue already has parent link fk' do
      let!(:work_item_parent_link) do
        work_item_parent_links.create!(
          work_item_id: issue_work_item.id,
          work_item_parent_id: epic_work_item.id,
          namespace_id: group.id
        )
      end

      let!(:epic_issue) do
        epic_issues.create!(
          epic_id: epic.id,
          issue_id: issue_work_item.id,
          namespace_id: group.id,
          work_item_parent_link_id: work_item_parent_link.id
        )
      end

      it 'does not change the existing work_item_parent_link_id' do
        expect do
          migration.perform
        end.not_to change { epic_issue.reload.work_item_parent_link_id }
      end
    end

    context 'when batch has mixed states: needs backfill, already set, and cannot backfill' do
      let!(:issue_work_item_2) do
        issues.create!(
          title: 'Second Child Issue',
          description: 'Second child issue',
          namespace_id: group.id,
          work_item_type_id: issue_type.id,
          author_id: author.id
        )
      end

      let!(:issue_work_item_3) do
        issues.create!(
          title: 'Third Child Issue',
          description: 'Third child issue',
          namespace_id: group.id,
          work_item_type_id: issue_type.id,
          author_id: author.id
        )
      end

      let!(:work_item_parent_link_1) do
        work_item_parent_links.create!(
          work_item_id: issue_work_item.id,
          work_item_parent_id: epic_work_item.id,
          namespace_id: group.id
        )
      end

      let!(:work_item_parent_link_2) do
        work_item_parent_links.create!(
          work_item_id: issue_work_item_2.id,
          work_item_parent_id: epic_work_item.id,
          namespace_id: group.id
        )
      end

      let!(:epic_issue_needs_backfill) do
        epic_issues.create!(
          epic_id: epic.id,
          issue_id: issue_work_item.id,
          namespace_id: group.id,
          work_item_parent_link_id: nil
        )
      end

      let!(:epic_issue_already_set) do
        epic_issues.create!(
          epic_id: epic.id,
          issue_id: issue_work_item_2.id,
          namespace_id: group.id,
          work_item_parent_link_id: work_item_parent_link_2.id
        )
      end

      let!(:epic_issue_no_parent_link) do
        epic_issues.create!(
          epic_id: epic.id,
          issue_id: issue_work_item_3.id,
          namespace_id: group.id,
          work_item_parent_link_id: nil
        )
      end

      it 'processes only the records that can be backfilled' do
        expect do
          migration.perform
        end.to change { epic_issue_needs_backfill.reload.work_item_parent_link_id }
          .from(nil)
          .to(work_item_parent_link_1.id)
          .and not_change { epic_issue_already_set.reload.work_item_parent_link_id }
          .and change { epic_issue_no_parent_link.reload.work_item_parent_link_id }.from(nil).to(be_present)
      end
    end

    context 'when no matching ParentLink exists for an EpicIssue' do
      let!(:epic_issue) do
        epic_issues.create!(
          epic_id: epic.id,
          issue_id: issue_work_item.id,
          namespace_id: group.id,
          work_item_parent_link_id: nil,
          relative_position: 100
        )
      end

      it 'creates a work_item_parent_link record and sets the work_item_parent_link_id' do
        expect do
          migration.perform
        end.to change { epic_issue.reload.work_item_parent_link_id }.from(nil).to(be_present)
          .and change { work_item_parent_links.count }.from(0).to(1)

        new_parent_link = work_item_parent_links.where(
          work_item_id: issue_work_item.id,
          work_item_parent_id: epic.issue_id,
          namespace_id: group.id,
          relative_position: 100
        ).first

        expect(new_parent_link).to be_present
        expect(epic_issue.work_item_parent_link_id).to eq(new_parent_link.id)
      end
    end

    context 'when no records within the sub-batch require backfill' do
      let!(:work_item_parent_link) do
        work_item_parent_links.create!(
          work_item_id: issue_work_item.id,
          work_item_parent_id: epic_work_item.id,
          namespace_id: group.id
        )
      end

      let!(:epic_issue) do
        epic_issues.create!(
          epic_id: epic.id,
          issue_id: issue_work_item.id,
          namespace_id: group.id,
          work_item_parent_link_id: work_item_parent_link.id
        )
      end

      it 'does not execute any updates' do
        expect(described_class::EpicIssues.connection).not_to receive(:execute)
        migration.perform
      end
    end
  end
end
