# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ApprovalGroupsFinder, "#execute", feature_category: :security_policy_management do
  let_it_be(:group_name) { "group-#{FFaker::Lorem.word}" }

  let_it_be(:container_a) { create(:group) }
  let_it_be(:group_a) { create(:group, parent: container_a, name: group_name) }
  let_it_be(:container_b) { create(:group) }
  let_it_be(:group_b) { create(:group, parent: container_b, name: group_name) }
  let_it_be(:user) { create(:user) }

  let(:groups) { [group_a, group_b] }
  let(:service) do
    described_class.new(group_ids: group_ids,
      group_paths: group_paths,
      user: user,
      container: container,
      search_globally: search_globally)
  end

  before do
    groups.each do |group|
      group.add_developer(user)
    end
  end

  context 'with inaccessible groups excluded' do
    subject do
      service.execute
    end

    let(:group_ids) { groups.map(&:id) }
    let(:group_paths) { groups.map(&:name) }
    let(:container) { group_a }
    let(:search_globally) { true }

    describe 'group ID lookup' do
      let(:group_ids) { group_a.id }
      let(:group_paths) { [] }

      it 'finds by group IDs' do
        expect(subject).to contain_exactly(group_a)
      end
    end

    describe 'group path lookup' do
      let(:group_ids) { [] }

      context 'when searching globally' do
        it 'finds across containers' do
          expect(subject).to contain_exactly(group_a, group_b)
        end
      end

      context 'when searching locally' do
        let(:search_globally) { false }

        it 'finds within container hierarchy' do
          expect(subject).to contain_exactly(group_a)
        end
      end
    end

    describe 'group ID and path lookup' do
      let(:group_ids) { [group_b.id] }
      let(:group_paths) { [group_name] }

      it 'combines' do
        expect(subject).to contain_exactly(group_a, group_b)
      end
    end

    describe 'authorization' do
      before do
        group_a.update_attribute(:visibility_level, Gitlab::VisibilityLevel::PRIVATE)
        group_a.members.delete_all
      end

      it 'excludes groups the user lacks access to',
        quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/435434' do
        expect(subject).to contain_exactly(group_b)
      end
    end

    context "with user namespace" do
      let(:container) { user.namespace }
      let(:search_globally) { false }
      let(:group_ids) { [group_a.id, group_b.id] }
      let(:group_paths) { [group_name] }

      it "finds globally accessible groups" do
        expect(subject).to contain_exactly(group_a, group_b)
      end
    end

    context "with nil container (policy fetched on self-managed instance)" do
      let(:container) { nil }
      let(:search_globally) { false }
      let(:group_ids) { [group_a.id, group_b.id] }
      let(:group_paths) { [group_name] }

      it "finds globally accessible groups" do
        expect(subject).to contain_exactly(group_a, group_b)
      end
    end
  end

  context "with inaccessible groups included" do
    subject do
      service.execute(include_inaccessible: true)
    end

    describe 'authorization' do
      let(:container) { group_a }
      let(:group_ids) { [group_a.id, group_b.id] }
      let(:group_paths) { [] }
      let(:search_globally) { true }

      before do
        group_a.update_attribute(:visibility_level, Gitlab::VisibilityLevel::PRIVATE)
        group_a.members.delete_all
      end

      it 'includes groups the user lacks access to' do
        expect(subject).to contain_exactly(group_a, group_b)
      end
    end
  end
end
