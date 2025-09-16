# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::CodeOwners::OwnerValidation::QualifiedGroupsFilter, feature_category: :source_code_management do
  let_it_be(:project) { create(:project, :in_subgroup) }
  let_it_be(:guest_group) { create(:project_group_link, :guest, project: project).group }
  let_it_be(:planner_group) { create(:project_group_link, :planner, project: project).group }
  let_it_be(:reporter_group) { create(:project_group_link, :reporter, project: project).group }
  let_it_be(:developer_group) { create(:project_group_link, :developer, project: project).group }
  let_it_be(:maintainer_group) { create(:project_group_link, :maintainer, project: project).group }
  let_it_be(:owner_group) { create(:project_group_link, :owner, project: project).group }
  let_it_be(:project_group) { project.group }
  let_it_be(:parent_group) { project_group.parent }
  let_it_be(:shared_with_parent_group) { create(:group_group_link, shared_with_group: parent_group).shared_group }
  let_it_be(:invited_subgroup_of_parent_group) do
    create(:project_group_link, project: project, group: create(:group, parent: parent_group)).group
  end

  let_it_be(:filter) do
    groups = [
      guest_group,
      planner_group,
      reporter_group,
      developer_group,
      maintainer_group,
      owner_group,
      project_group,
      parent_group,
      shared_with_parent_group,
      invited_subgroup_of_parent_group
    ]

    group_names = groups.map(&:full_path)

    described_class.new(project, groups: groups, group_names: group_names)
  end

  describe '#output_groups' do
    it 'returns ancestoral groups and invited groups with developer access' do
      expect(filter.output_groups).to contain_exactly(
        developer_group,
        maintainer_group,
        owner_group,
        project_group,
        parent_group,
        invited_subgroup_of_parent_group
      )
    end
  end

  describe '#valid_group_names' do
    it 'returns all group names that match a qualified group' do
      expect(filter.valid_group_names).to contain_exactly(
        developer_group.full_path,
        maintainer_group.full_path,
        owner_group.full_path,
        project_group.full_path,
        parent_group.full_path,
        invited_subgroup_of_parent_group.full_path
      )
    end
  end

  describe '#invalid_group_names' do
    it 'returns all group names that do not match a qualified group' do
      expect(filter.invalid_group_names).to contain_exactly(
        guest_group.full_path,
        planner_group.full_path,
        reporter_group.full_path,
        shared_with_parent_group.full_path
      )
    end
  end

  describe '#error_message' do
    it 'returns an error message key to be applied to invalid entries' do
      expect(filter.error_message).to eq(:unqualified_group)
    end
  end

  describe '#valid_entry?(references)' do
    let(:references) { instance_double(Gitlab::CodeOwners::ReferenceExtractor, names: names) }
    let(:names) { ['bar'] }
    let(:invalid_group_names) { ['foo'] }

    before do
      allow(filter).to receive(:invalid_group_names).and_return(invalid_group_names)
    end

    context 'when references contains no invalid references' do
      it 'returns true' do
        expect(filter.valid_entry?(references)).to be(true)
      end
    end

    context 'when references.names includes invalid_group_names' do
      let(:names) { %w[foo bar] }

      it 'returns false' do
        expect(filter.valid_entry?(references)).to be(false)
      end
    end
  end

  it 'does not perform N+1 queries', :request_store, :use_sql_query_cache do
    project_id = project.id
    # refind the project to ensure the associations aren't loaded
    project = Project.find(project_id)
    groups = [
      guest_group,
      planner_group,
      reporter_group,
      developer_group,
      maintainer_group,
      owner_group,
      project_group,
      parent_group
    ]
    group_names = groups.map(&:full_path)

    control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
      filter = described_class.new(project, groups: groups, group_names: group_names)
      filter.output_groups
      filter.invalid_group_names
      filter.valid_group_names
    end
    # Reset the request store to ensure the cache isn't warm
    RequestStore.clear!

    # refind the project and groups to ensure the associations aren't loaded
    project = Project.find(project_id)
    additional_group = create(:project_group_link, project: project).group
    groups << additional_group
    group_names << additional_group.full_path

    expect do
      filter = described_class.new(project, groups: groups, group_names: group_names)
      filter.output_groups
      filter.invalid_group_names
      filter.valid_group_names
    end.to issue_same_number_of_queries_as(control)
  end
end
