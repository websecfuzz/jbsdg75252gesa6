# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Groups::Menus::SettingsMenu, feature_category: :navigation do
  let_it_be(:owner) { create(:user) }
  let_it_be(:auditor) { create(:user, :auditor) }
  let_it_be(:maintainer) { create(:user, :maintainer) }

  let_it_be_with_refind(:group) do
    build(:group, :private).tap do |g|
      g.add_owner(owner)
      g.add_member(maintainer, :maintainer)
      g.add_member(auditor, :reporter)
    end
  end

  let_it_be_with_refind(:subgroup) { create(:group, :private, parent: group) }
  let(:show_promotions) { false }
  let(:container) { group }
  let(:context) { Sidebars::Groups::Context.new(current_user: user, container: container, show_promotions: show_promotions) }
  let(:menu) { described_class.new(context) }

  describe 'Menu Items' do
    context 'for owner user' do
      let(:user) { owner }

      subject { menu.renderable_items.find { |e| e.item_id == item_id } }

      describe 'Service accounts menu', feature_category: :user_management do
        let(:item_id) { :service_accounts }

        before do
          stub_ee_application_setting(allow_top_level_group_owners_to_create_service_accounts: true)
          stub_licensed_features(service_accounts: true)
        end

        it { is_expected.to be_present }

        context 'when it is not a root group' do
          let_it_be_with_refind(:subgroup) do
            create(:group, :private, parent: group, owners: [owner])
          end

          let(:container) { subgroup }

          it { is_expected.not_to be_present }
        end

        context 'when service accounts feature is not included in the license' do
          before do
            stub_licensed_features(service_accounts: false)
          end

          it { is_expected.not_to be_present }
        end
      end

      describe 'Roles and permissions menu', feature_category: :user_management do
        using RSpec::Parameterized::TableSyntax

        let(:item_id) { :roles_and_permissions }

        where(license: [:custom_roles, :default_roles_assignees])

        with_them do
          context 'when feature is licensed' do
            before do
              stub_licensed_features(license => true)
              stub_saas_features(gitlab_com_subscriptions: true)
            end

            it { is_expected.to be_present }

            context 'when it is not a root group' do
              let_it_be_with_refind(:subgroup) do
                create(:group, :private, parent: group).tap do |g|
                  g.add_owner(owner)
                end
              end

              let(:container) { subgroup }

              it { is_expected.not_to be_present }
            end

            context 'when on self-managed' do
              before do
                stub_saas_features(gitlab_com_subscriptions: false)
              end

              it { is_expected.not_to be_present }
            end
          end

          context 'when feature is not licensed' do
            before do
              stub_licensed_features(license => false)
              stub_saas_features(gitlab_com_subscriptions: true)
            end

            it { is_expected.not_to be_present }
          end
        end
      end

      describe 'LDAP sync menu' do
        let(:item_id) { :ldap_sync }

        before do
          allow(Gitlab::Auth::Ldap::Config).to receive(:group_sync_enabled?).and_return(sync_enabled)
        end

        context 'when group LDAP sync is not enabled' do
          let(:sync_enabled) { false }

          it { is_expected.not_to be_present }
        end

        context 'when group LDAP sync is enabled' do
          let(:sync_enabled) { true }

          context 'when user can admin LDAP syncs' do
            it { is_expected.to be_present }
          end

          context 'when user cannot admin LDAP syncs' do
            let(:user) { nil }

            it { is_expected.not_to be_present }
          end
        end
      end

      describe 'SAML SSO menu' do
        let(:item_id) { :saml_sso }
        let(:saml_enabled) { true }

        before do
          stub_licensed_features(group_saml: saml_enabled)
          allow(::Gitlab::Auth::GroupSaml::Config).to receive(:enabled?).and_return(saml_enabled)
        end

        context 'when SAML is disabled' do
          let(:saml_enabled) { false }

          it { is_expected.not_to be_present }
        end

        context 'when SAML is enabled' do
          it { is_expected.to be_present }

          context 'when user cannot admin group SAML' do
            let(:user) { nil }

            it { is_expected.not_to be_present }
          end
        end
      end

      describe 'SAML group links menu' do
        let(:item_id) { :saml_group_links }
        let(:saml_group_links_enabled) { true }

        before do
          allow(::Gitlab::Auth::GroupSaml::Config).to receive(:enabled?).and_return(saml_group_links_enabled)
          allow(group).to receive(:saml_group_sync_available?).and_return(saml_group_links_enabled)
        end

        context 'when SAML group links feature is disabled' do
          let(:saml_group_links_enabled) { false }

          it { is_expected.not_to be_present }
        end

        context 'when SAML group links feature is enabled' do
          it { is_expected.to be_present }

          context 'when user cannot admin SAML group links' do
            let(:user) { nil }

            it { is_expected.not_to be_present }
          end
        end
      end

      describe 'domain verification', :saas do
        let(:item_id) { :domain_verification }

        context 'when domain verification is licensed' do
          before do
            stub_licensed_features(domain_verification: true)
          end

          it { is_expected.to be_present }

          context 'when user cannot admin group' do
            let(:user) { nil }

            it { is_expected.not_to be_present }
          end
        end

        context 'when domain verification is not licensed' do
          before do
            stub_licensed_features(domain_verification: false)
          end

          it { is_expected.not_to be_present }
        end
      end

      describe 'Webhooks menu' do
        let(:item_id) { :webhooks }
        let(:group_webhooks_enabled) { true }

        before do
          stub_licensed_features(group_webhooks: group_webhooks_enabled)
        end

        context 'when licensed feature :group_webhooks is not enabled' do
          let(:group_webhooks_enabled) { false }

          it { is_expected.not_to be_present }
        end

        context 'when show_promotions is enabled' do
          let(:show_promotions) { true }

          it { is_expected.to be_present }
        end

        context 'when licensed feature :group_webhooks is enabled' do
          it { is_expected.to be_present }
        end
      end

      describe 'Usage quotas menu' do
        let(:item_id) { :usage_quotas }

        it { is_expected.to be_present }

        context 'when subgroup' do
          let(:container) { subgroup }

          it { is_expected.not_to be_present }
        end
      end

      describe 'GitLab Duo menu' do
        let(:item_id) { :gitlab_duo_settings }

        before do
          stub_saas_features(gitlab_com_subscriptions: true)
          stub_licensed_features(code_suggestions: true)
          add_on = create(:gitlab_subscription_add_on)
          create(:gitlab_subscription_add_on_purchase, quantity: 50, namespace: group, add_on: add_on)
          allow(group).to receive(:usage_quotas_enabled?).and_return(true)
        end

        it { is_expected.to be_present }

        context 'when subgroup' do
          let(:container) { subgroup }

          it { is_expected.not_to be_present }
        end
      end

      describe 'Billing menu' do
        let(:item_id) { :billing }
        let(:check_billing) { true }

        before do
          allow(::Gitlab::CurrentSettings).to receive(:should_check_namespace_plan?).and_return(check_billing)
        end

        it { is_expected.to be_present }

        context 'when group billing does not apply' do
          let(:check_billing) { false }

          it { is_expected.not_to be_present }
        end
      end

      describe 'Reporting menu' do
        let(:item_id) { :reporting }
        let(:feature_enabled) { true }

        before do
          allow(group).to receive(:unique_project_download_limit_enabled?) { feature_enabled }
        end

        it { is_expected.to be_present }

        context 'when feature is not enabled' do
          let(:feature_enabled) { false }

          it { is_expected.not_to be_present }
        end
      end

      describe 'Analytics menu' do
        let(:item_id) { :analytics }
        let(:feature_enabled) { true }

        before do
          allow(menu).to receive(:group_analytics_settings_available?).with(user, group).and_return(feature_enabled)
          menu.configure_menu_items
        end

        it { is_expected.to be_present }

        context 'when feature is not enabled' do
          let(:feature_enabled) { false }

          it { is_expected.not_to be_present }
        end
      end

      describe 'Workspaces menu item' do
        let(:item_id) { :workspaces_settings }

        context 'when workspaces feature is available' do
          before do
            stub_licensed_features(remote_development: true)
          end

          it { is_expected.to be_present }
        end

        context 'when workspaces feature is not available' do
          before do
            stub_licensed_features(remote_development: false)
          end

          it { is_expected.not_to be_present }
        end
      end
    end

    context 'for maintainer user' do
      let(:user) { maintainer }

      subject { menu.renderable_items.find { |e| e.item_id == item_id } }

      describe 'Issues menu item' do
        let(:item_id) { :group_work_items_settings }
        let(:custom_fields_licensed) { true }

        before do
          stub_licensed_features(custom_fields: custom_fields_licensed)
        end

        it { is_expected.to be_present }

        context 'when custom_fields is not licensed' do
          let(:custom_fields_licensed) { false }

          it { is_expected.not_to be_present }
        end

        context 'when subgroup' do
          let(:container) { subgroup }

          it { is_expected.not_to be_present }
        end
      end
    end

    context 'for auditor user' do
      let(:user) { auditor }

      subject { menu.renderable_items.find { |e| e.item_id == item_id } }

      describe 'Roles and permissions menu', feature_category: :user_management do
        let(:item_id) { :roles_and_permissions }

        before do
          stub_licensed_features(custom_roles: true)
        end

        it { is_expected.not_to be_present }
      end

      describe 'Billing menu item' do
        let(:item_id) { :billing }
        let(:check_billing) { true }

        before do
          allow(::Gitlab::CurrentSettings).to receive(:should_check_namespace_plan?).and_return(check_billing)
        end

        it { is_expected.to be_present }

        it 'does not show any other menu items' do
          expect(menu.renderable_items.length).to equal(1)
        end
      end

      describe 'Issues menu item' do
        let(:item_id) { :group_work_items }

        before do
          stub_licensed_features(custom_fields: true)
        end

        it { is_expected.not_to be_present }
      end
    end

    describe 'Custom Roles' do
      using RSpec::Parameterized::TableSyntax

      let_it_be_with_reload(:user) { create(:user) }
      let_it_be_with_reload(:group) { create(:group) }
      let_it_be_with_reload(:sub_group) { create(:group, parent: group) }

      let(:context) { Sidebars::Groups::Context.new(current_user: user, container: sub_group) }
      let(:menu) { described_class.new(context) }

      subject(:menu_items) { menu.renderable_items }

      before do
        stub_licensed_features(custom_roles: true, custom_compliance_frameworks: true)
      end

      where(:ability, :menu_item) do
        :admin_cicd_variables          | 'CI/CD'
        :admin_compliance_framework    | 'General'
        :admin_push_rules              | 'Repository'
        :admin_protected_environments  | 'CI/CD'
        :admin_runners                 | 'CI/CD'
        :manage_deploy_tokens          | 'Repository'
        :manage_group_access_tokens    | 'Access tokens'
        :manage_merge_request_settings | 'General'
        :remove_group                  | 'General'
        :admin_integrations            | 'Integrations'
        :admin_web_hook                | 'Webhooks'
      end

      with_them do
        describe "when the user has the `#{params[:ability]}` custom ability" do
          let!(:role) { create(:member_role, :guest, ability, namespace: group) }
          let!(:membership) { create(:group_member, :guest, member_role: role, user: user, group: group) }

          it { is_expected.to include(have_attributes(title: menu_item)) }

          it 'does not show any other menu items' do
            expect(menu_items.length).to eq(1)
          end
        end
      end
    end
  end
end
