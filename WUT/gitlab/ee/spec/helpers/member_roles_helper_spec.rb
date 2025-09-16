# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MemberRolesHelper, feature_category: :permissions do
  include ApplicationHelper

  let_it_be(:user) { build_stubbed(:user) }
  let_it_be(:source) { build_stubbed(:group) }
  let_it_be(:root_group) { source.root_ancestor }

  before do
    stub_licensed_features(custom_roles: true)
    allow(helper).to receive(:current_user).and_return(user)
  end

  shared_examples 'no LDAP data' do
    it 'does not have LDAP servers data' do
      expect(data).not_to have_key(:ldap_servers)
    end

    it 'does not have LDAP users path' do
      expect(data).not_to have_key(:ldap_users_path)
    end
  end

  describe '#member_roles_data' do
    context 'when on self-managed' do
      subject(:data) { helper.member_roles_data }

      it_behaves_like 'no LDAP data'

      it 'matches the expected data' do
        expect(data[:new_role_path]).to be_nil
        expect(data[:group_full_path]).to be_nil
        expect(data[:group_id]).to be_nil
        expect(data[:current_user_email]).to eq user.notification_email_or_default
      end

      context 'with admin member role rights' do
        before do
          allow(helper).to receive(:can?).with(user, :admin_member_role).and_return(true)
          allow(helper).to receive(:can?).with(user, :manage_ldap_admin_links).and_return(true)
          allow(Gitlab.config.ldap).to receive(:enabled).and_return(true)
        end

        it 'matches the expected data' do
          expect(data[:new_role_path]).to eq new_admin_application_settings_roles_and_permission_path
          expect(data[:group_full_path]).to be_nil
          expect(data[:group_id]).to be_nil
          expect(data[:current_user_email]).to eq user.notification_email_or_default
          expect(data[:ldap_servers]).to eq '[{"text":"ldap","value":"ldapmain"}]'
          expect(data[:ldap_users_path]).to eq '/admin/users?filter=ldap_sync'
        end

        context 'when user cannot manage ldap admin links' do
          before do
            allow(helper).to receive(:can?).with(user, :manage_ldap_admin_links).and_return(false)
          end

          it_behaves_like 'no LDAP data'
        end

        context 'when LDAP is not enabled for the instance' do
          before do
            allow(Gitlab.config.ldap).to receive(:enabled).and_return(false)
          end

          it_behaves_like 'no LDAP data'
        end
      end
    end

    context 'when on SaaS', :saas do
      context 'when on group page' do
        subject(:data) { helper.member_roles_data(source) }

        it_behaves_like 'no LDAP data'

        it 'matches the expected data' do
          expect(data[:new_role_path]).to be_nil
          expect(data[:group_full_path]).to eq source.full_path
          expect(data[:group_id]).to eq source.id
          expect(data[:current_user_email]).to eq user.notification_email_or_default
        end

        context 'with admin member role rights' do
          before do
            allow(helper).to receive(:can?).with(user, :admin_member_role, root_group).and_return(true)
            allow(helper).to receive(:can?).with(user, :manage_ldap_admin_links).and_return(true)
            allow(Gitlab.config.ldap).to receive(:enabled).and_return(true)
          end

          it 'matches the expected data' do
            expect(data[:new_role_path]).to eq new_group_settings_roles_and_permission_path(source)
            expect(data[:group_full_path]).to eq source.full_path
            expect(data[:group_id]).to eq source.id
            expect(data[:current_user_email]).to eq user.notification_email_or_default
          end
        end
      end
    end
  end

  describe '#manage_member_roles_path' do
    subject { helper.manage_member_roles_path(source) }

    context 'when on SaaS', :saas do
      it { is_expected.to be_nil }

      context 'as owner' do
        before do
          allow(helper).to receive(:can?).with(user, :admin_group_member, root_group).and_return(true)
        end

        it { is_expected.to eq(group_settings_roles_and_permissions_path(root_group)) }

        context 'when custom roles are not available' do
          before do
            stub_licensed_features(custom_roles: false)
          end

          it { is_expected.to be_nil }
        end
      end
    end

    context 'when in admin mode', :enable_admin_mode do
      it { is_expected.to be_nil }

      context 'as admin' do
        let_it_be(:user) { build_stubbed(:user, :admin) }

        it { is_expected.to eq(admin_application_settings_roles_and_permissions_path) }

        context 'when custom roles are not available' do
          before do
            stub_licensed_features(custom_roles: false)
          end

          it { is_expected.to be_nil }
        end
      end
    end
  end

  describe '#member_role_edit_path' do
    context 'when on self-managed' do
      subject { helper.member_role_edit_path(role) }

      let_it_be(:role) { build_stubbed(:member_role, id: 5) }

      it { is_expected.to eq(edit_admin_application_settings_roles_and_permission_path(role)) }
    end

    context 'when on Saas', :saas do
      subject { helper.member_role_edit_path(role) }

      let_it_be(:role) { build_stubbed(:member_role, id: 5, namespace: source) }

      it { is_expected.to eq(edit_group_settings_roles_and_permission_path(source, role)) }
    end
  end

  describe '#member_role_details_path' do
    subject { helper.member_role_details_path(role) }

    let_it_be(:role) { build_stubbed(:member_role, id: 5, namespace: root_group) }

    context 'when on self-managed' do
      it { is_expected.to eq(admin_application_settings_roles_and_permission_path(role)) }
    end

    context 'when on Saas', :saas do
      it { is_expected.to eq(group_settings_roles_and_permission_path(root_group, role)) }
    end
  end
end
