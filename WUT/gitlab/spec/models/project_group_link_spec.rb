# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProjectGroupLink, feature_category: :groups_and_projects do
  describe "Associations" do
    it { is_expected.to belong_to(:group) }
    it { is_expected.to belong_to(:project) }
  end

  describe "Validation" do
    let(:parent_group) { create(:group) }
    let(:group) { create(:group, parent: parent_group) }
    let(:project) { create(:project, group: group) }
    let!(:project_group_link) { create(:project_group_link, project: project) }

    it { is_expected.to validate_presence_of(:project_id) }
    it { is_expected.to validate_presence_of(:group) }
    it { is_expected.to validate_presence_of(:group_access) }
    it { is_expected.to validate_inclusion_of(:group_access).in_array(Gitlab::Access.all_values) }

    it 'validates uniqueness of project_id with correct message' do
      is_expected.to validate_uniqueness_of(:project_id)
                       .scoped_to(:group_id)
                       .with_message('already shared with this group')
    end

    it "doesn't allow a project to be shared with the group it is in" do
      project_group_link.group = group

      expect(project_group_link).not_to be_valid
    end

    it "doesn't allow a project to be shared with an ancestor of the group it is in" do
      project_group_link.group = parent_group

      expect(project_group_link).not_to be_valid
    end
  end

  describe 'scopes' do
    describe '.non_guests' do
      let!(:project_group_link_reporter) { create :project_group_link, :reporter }
      let!(:project_group_link_maintainer) { create :project_group_link, :maintainer }
      let!(:project_group_link_developer) { create :project_group_link }
      let!(:project_group_link_guest) { create :project_group_link, :guest }

      it 'returns all records which are greater than Guests access' do
        expect(described_class.non_guests).to match_array([
          project_group_link_reporter,
                                                            project_group_link_developer,
                                                            project_group_link_maintainer
        ])
      end
    end
  end

  describe '#prevent_concurrent_inserts' do
    let_it_be(:project) { create(:project) }
    let_it_be(:group) { create(:group) }
    let_it_be(:project_group_link) { build(:project_group_link, project: project, group: group) }
    let(:connection) { ApplicationRecord.connection }

    context 'when project_id and group_id are present' do
      it 'acquires an advisory lock' do
        lock_key = ['project_group_links', project.id, group.id].join('-')
        lock_expression = "hashtext(#{connection.quote(lock_key)})"

        expect(connection).to receive(:execute).with("SELECT pg_advisory_xact_lock(#{lock_expression})")

        project_group_link.send(:prevent_concurrent_inserts)
      end

      it 'uses a unique lock key based on project_id and group_id' do
        expected_lock_key = ['project_group_links', project.id, group.id].join('-')

        expect(project_group_link).to receive(:connection).at_least(:once).and_return(connection)
        expect(connection).to receive(:quote).with(expected_lock_key).and_call_original
        expect(connection).to receive(:execute).with(/SELECT pg_advisory_xact_lock/)

        project_group_link.send(:prevent_concurrent_inserts)
      end
    end

    context 'when project_id is nil' do
      let(:project_group_link) { build(:project_group_link, project: nil, group: group) }

      it 'returns early without acquiring a lock' do
        expect(project_group_link.connection).not_to receive(:execute)

        project_group_link.send(:prevent_concurrent_inserts)
      end
    end

    context 'when group_id is nil' do
      let(:project_group_link) { build(:project_group_link, project: project, group: nil) }

      it 'returns early without acquiring a lock' do
        expect(project_group_link.connection).not_to receive(:execute)

        project_group_link.send(:prevent_concurrent_inserts)
      end
    end

    context 'when both project_id and group_id are nil' do
      let(:project_group_link) { build(:project_group_link, project: nil, group: nil) }

      it 'returns early without acquiring a lock' do
        expect(project_group_link.connection).not_to receive(:execute)

        project_group_link.send(:prevent_concurrent_inserts)
      end
    end
  end

  describe 'search by group name' do
    let_it_be(:project_group_link) { create(:project_group_link) }
    let_it_be(:group) { project_group_link.group }

    it { expect(described_class.search(group.name)).to eq([project_group_link]) }
    it { expect(described_class.search('not-a-group-name')).to be_empty }
  end

  describe '#owner_access?' do
    it 'returns true for links with OWNER access' do
      link = create(:project_group_link, :owner)

      expect(link.owner_access?).to eq(true)
    end

    it 'returns false for links without OWNER access' do
      link = create(:project_group_link, :guest)

      expect(link.owner_access?).to eq(false)
    end
  end

  describe '#human_access' do
    it 'delegates to Gitlab::Access' do
      project_group_link = create(:project_group_link, :reporter)
      expect(Gitlab::Access).to receive(:human_access).with(project_group_link.group_access).and_call_original

      expect(project_group_link.human_access).to eq('Reporter')
    end
  end
end
