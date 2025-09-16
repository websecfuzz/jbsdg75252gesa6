# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Projects::Menus::SettingsMenu, feature_category: :navigation do
  let_it_be(:project) { create(:project) }

  let(:user) { project.first_owner }

  let(:show_promotions) { true }
  let(:show_discover_project_security) { true }
  let(:context) do
    Sidebars::Projects::Context.new(current_user: user, container: project, show_promotions: show_promotions,
      show_discover_project_security: show_discover_project_security)
  end

  let(:menu) { described_class.new(context) }

  describe 'Menu items' do
    subject { menu.renderable_items.find { |e| e.item_id == item_id } }

    describe 'Analytics' do
      let(:item_id) { :analytics }

      let(:feature_enabled) { true }

      before do
        allow(menu).to receive(:product_analytics_settings_allowed?).and_return(feature_enabled)
        menu.configure_menu_items
      end

      it 'includes the analytics menu item' do
        expect(subject.title).to eql('Analytics')
      end

      context 'when feature is not enabled' do
        let(:feature_enabled) { false }

        it { is_expected.to be_nil }
      end
    end

    describe 'General' do
      let(:item_id) { :general }

      describe 'when the user is not an admin' do
        let_it_be(:user) { create(:user) }

        before_all do
          project.add_guest(user)
        end

        before do
          allow(Ability).to receive(:allowed?).and_call_original
        end

        it 'does not include the general menu item' do
          expect(subject).to be_nil
        end

        context 'when the user has the `view_edit_page` ability' do
          before do
            allow(Ability).to receive(:allowed?).with(user, :view_edit_page, project).and_return(true)
          end

          it 'includes the general menu item' do
            expect(subject.title).to eql('General')
          end
        end
      end
    end
  end

  describe 'Custom Roles' do
    using RSpec::Parameterized::TableSyntax

    let_it_be_with_reload(:user) { create(:user) }
    let_it_be_with_reload(:project) { create(:project, :in_group) }

    let(:context) { Sidebars::Projects::Context.new(current_user: user, container: project) }

    subject(:menu_items) { menu.renderable_items }

    before do
      stub_licensed_features(custom_roles: true)
    end

    where(:ability, :menu_item) do
      :admin_cicd_variables          | 'CI/CD'
      :admin_push_rules              | 'Repository'
      :manage_protected_tags         | 'Repository'
      :admin_protected_branch        | 'Repository'
      :admin_protected_environments  | 'CI/CD'
      :admin_runners                 | 'CI/CD'
      :manage_deploy_tokens          | 'Repository'
      :manage_merge_request_settings | 'Merge requests'
      :manage_project_access_tokens  | 'Access tokens'
      :admin_integrations            | 'Integrations'
      :admin_web_hook                | 'Webhooks'
    end

    with_them do
      describe "when the user has the `#{params[:ability]}` custom ability" do
        let!(:role) { create(:member_role, :guest, ability, namespace: project.group) }
        let!(:membership) { create(:project_member, :guest, member_role: role, user: user, project: project) }

        it { is_expected.to include(have_attributes(title: menu_item)) }
      end
    end
  end
end
