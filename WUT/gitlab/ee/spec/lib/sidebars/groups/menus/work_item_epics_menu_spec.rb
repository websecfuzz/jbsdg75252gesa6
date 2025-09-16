# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Groups::Menus::WorkItemEpicsMenu, feature_category: :navigation do
  let_it_be(:owner) { create(:user) }
  let_it_be(:group) do
    build(:group, :private).tap do |g|
      g.add_owner(owner)
    end
  end

  let(:user) { owner }
  let(:context) { Sidebars::Groups::Context.new(current_user: user, container: group) }
  let(:menu) { described_class.new(context) }

  describe 'Menu Items' do
    subject { menu.renderable_items }

    before do
      stub_licensed_features(epics: true)
    end

    describe 'when the user has access to epics' do
      it 'has all the menus' do
        expect(subject.map(&:item_id)).to include(:group_epic_list, :roadmap)
      end
    end

    describe 'when the user does not have access' do
      let(:user) { nil }

      it { is_expected.to be_empty }
    end
  end

  it_behaves_like 'serializable as super_sidebar_menu_args' do
    let(:extra_attrs) do
      {
        item_id: :boards,
        pill_count: menu.pill_count,
        pill_count_field: menu.pill_count_field,
        has_pill: menu.has_pill?,
        link: "/groups/#{group.full_path}/-/epic_boards",
        super_sidebar_parent: Sidebars::Groups::SuperSidebarMenus::PlanMenu
      }
    end
  end

  describe '#pill_count_field' do
    it 'returns the correct GraphQL field name' do
      expect(menu.pill_count_field).to eq('openEpicsCount')
    end
  end

  describe '#sprite_icon' do
    subject { menu.sprite_icon }

    it { is_expected.to eq 'epic' }
  end
end
