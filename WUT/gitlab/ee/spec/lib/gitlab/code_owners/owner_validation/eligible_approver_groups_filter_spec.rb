# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::CodeOwners::OwnerValidation::EligibleApproverGroupsFilter, feature_category: :source_code_management do
  let_it_be(:project) { create(:project, :in_subgroup) }
  let_it_be(:invited_group_with_approver) { create(:project_group_link, project: project).group }
  let_it_be(:invited_group_with_inherited_approver) { create(:project_group_link, project: project).group }
  let_it_be(:project_group_with_inherited_approver) { project.group }
  let_it_be(:parent_group_with_approver) { project.group.parent }

  let_it_be(:filter) do
    groups = [
      invited_group_with_approver,
      invited_group_with_inherited_approver,
      project_group_with_inherited_approver,
      parent_group_with_approver
    ]
    group_names = groups.map(&:full_path)

    described_class.new(project, groups: groups, group_names: group_names)
  end

  before_all do
    create(:user, developer_of: invited_group_with_approver)
    invited_group = create(:group_group_link, shared_with_group: invited_group_with_inherited_approver).shared_group
    create(:user, developer_of: invited_group)
    create(:user, owner_of: parent_group_with_approver)
  end

  describe '#output_groups' do
    it 'returns groups with at least one direct member who can approve' do
      expect(filter.output_groups).to contain_exactly(
        invited_group_with_approver,
        parent_group_with_approver
      )
    end
  end

  describe '#invalid_group_names' do
    it 'returns all group names that do not match an eligible approver group' do
      expect(filter.invalid_group_names).to contain_exactly(
        invited_group_with_inherited_approver.full_path,
        project_group_with_inherited_approver.full_path
      )
    end
  end

  describe '#valid_group_names' do
    it 'returns all group names that match an eligible approver group' do
      expect(filter.valid_group_names).to contain_exactly(
        invited_group_with_approver.full_path,
        parent_group_with_approver.full_path
      )
    end
  end

  describe '#error_message' do
    it 'returns an error message key to be applied to invalid entries' do
      expect(filter.error_message).to eq(:group_without_eligible_approvers)
    end
  end

  # Increasing the number of groups should not result in N+1 queries
  it 'avoids N+1 queries', :request_store, :use_sql_query_cache do
    # Reload the project manually, outside of the control
    project_id = project.id
    project = Project.find(project_id)
    groups = [
      invited_group_with_approver,
      invited_group_with_inherited_approver,
      project_group_with_inherited_approver,
      parent_group_with_approver
    ]
    group_names = groups.map(&:full_path)

    control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
      filter = described_class.new(project, groups: groups, group_names: group_names)
      filter.output_groups
      filter.valid_group_names
      filter.invalid_group_names
    end
    # Clear the RequestStore to ensure we do not have a warm cache
    RequestStore.clear!

    extra_group_without_approver = create(:project_group_link, project: project).group
    extra_group_with_approver = create(:project_group_link, project: project).group
    create(:user, developer_of: extra_group_with_approver)

    groups += [extra_group_without_approver, extra_group_with_approver]
    group_names = groups.map(&:full_path)
    # Refind the project to reset the associations
    project = Project.find(project_id)

    expect do
      filter = described_class.new(project, groups: groups, group_names: group_names)
      filter.output_groups
      filter.valid_group_names
      filter.invalid_group_names
    end.not_to exceed_query_limit(control.count - 1)
  end
end
