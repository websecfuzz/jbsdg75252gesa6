# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Groups::Menus::PackagesRegistriesMenu, feature_category: :navigation do
  let_it_be(:owner) { create(:user) }
  let_it_be_with_reload(:group) do
    build(:group, :private).tap do |g|
      g.add_owner(owner)
    end
  end

  let(:user) { owner }
  let(:context) { Sidebars::Groups::Context.new(current_user: user, container: group) }
  let(:menu) { described_class.new(context) }

  it_behaves_like 'not serializable as super_sidebar_menu_args'

  describe '#render?' do
    context 'when menu has menu items to show' do
      it 'returns true' do
        expect(menu.render?).to be true
      end
    end
  end

  describe 'Menu items' do
    subject { find_menu(menu, item_id) }

    describe 'Virtual Registry' do
      let(:item_id) { :virtual_registry }

      context 'when user can read virtual registry' do
        before do
          stub_config(dependency_proxy: { enabled: true })
          stub_licensed_features(packages_virtual_registry: true)
        end

        context 'when all conditions are met' do
          it { is_expected.not_to be_nil }
        end

        context 'when ui_for_virtual_registries feature flag is disabled' do
          before do
            stub_feature_flags(ui_for_virtual_registries: false)
          end

          it { is_expected.to be_nil }
        end

        context 'when maven_virtual_registry feature flag is disabled' do
          before do
            stub_feature_flags(maven_virtual_registry: false)
          end

          it { is_expected.to be_nil }
        end

        context 'when dependency proxy is disabled' do
          before do
            stub_config(dependency_proxy: { enabled: false })
          end

          it { is_expected.to be_nil }
        end

        context 'when licensed feature is not available' do
          before do
            stub_licensed_features(packages_virtual_registry: false)
          end

          it { is_expected.to be_nil }
        end
      end

      context 'when user cannot read virtual registry' do
        let(:user) { nil }

        before do
          stub_config(dependency_proxy: { enabled: true })
          stub_licensed_features(packages_virtual_registry: true)
        end

        it { is_expected.to be_nil }
      end

      context 'when user has limited permissions' do
        let(:user) { create(:user) }

        before do
          stub_config(dependency_proxy: { enabled: true })
          stub_licensed_features(packages_virtual_registry: true)
        end

        it { is_expected.to be_nil }
      end

      context 'when group is not root' do
        let(:group) { create(:group, parent: create(:group)) }

        before do
          stub_config(dependency_proxy: { enabled: true })
          stub_licensed_features(packages_virtual_registry: true)
        end

        it { is_expected.to be_nil }
      end
    end
  end

  private

  def find_menu(menu, item)
    menu.renderable_items.find { |i| i.item_id == item }
  end
end
