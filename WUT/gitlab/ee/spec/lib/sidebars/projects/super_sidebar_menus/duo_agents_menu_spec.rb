# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Projects::SuperSidebarMenus::DuoAgentsMenu, feature_category: :duo_workflow do
  let_it_be(:project) { build(:project) }
  let_it_be(:user) { build(:user) }
  let(:context) { Sidebars::Projects::Context.new(current_user: user, container: project) }

  subject(:menu) { described_class.new(context) }

  describe '#configure_menu_items' do
    before do
      stub_feature_flags(duo_workflow_in_ci: true)
    end

    it 'returns true and adds menu items' do
      expect(menu.configure_menu_items).to be true
    end

    it 'adds agents runs menu item' do
      menu.configure_menu_items

      expect(menu.renderable_items.size).to eq(2)
      expect(menu.renderable_items.first.item_id).to eq(:agents_runs)
    end

    context 'when duo_workflow_in_ci feature is disabled' do
      before do
        stub_feature_flags(duo_workflow_in_ci: false)
      end

      it 'returns false' do
        expect(menu.configure_menu_items).to be false
      end

      it 'does not add menu items' do
        menu.configure_menu_items

        expect(menu.renderable_items).to be_empty
      end
    end
  end

  describe '#title' do
    it 'returns correct title' do
      expect(menu.title).to eq('Automate')
    end
  end

  describe '#sprite_icon' do
    it 'returns correct icon' do
      expect(menu.sprite_icon).to eq('tanuki-ai')
    end
  end

  describe 'agents runs menu item' do
    before do
      menu.configure_menu_items
    end

    let(:menu_item) { menu.renderable_items.first }

    it 'has correct title' do
      expect(menu_item.title).to eq('Agent sessions')
    end

    it 'has correct link' do
      expect(menu_item.link).to eq("/#{project.full_path}/-/automate/agent-sessions")
    end

    it 'has correct active routes' do
      expect(menu_item.active_routes).to eq({ controller: :duo_agents_platform })
    end

    it 'has correct item id' do
      expect(menu_item.item_id).to eq(:agents_runs)
    end
  end
end
