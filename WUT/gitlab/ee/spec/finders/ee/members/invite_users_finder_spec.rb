# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Members::InviteUsersFinder, feature_category: :groups_and_projects do
  let_it_be(:current_user) { create(:user) }
  let_it_be(:root_group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: root_group) }
  let_it_be(:project) { create(:project, namespace: root_group, creator: current_user) }

  let_it_be(:regular_user) { create(:user) }
  let_it_be(:admin_user) { create(:user, :admin) }
  let_it_be(:banned_user) { create(:user, :banned) }
  let_it_be(:blocked_user) { create(:user, :blocked) }
  let_it_be(:ldap_blocked_user) { create(:user, :ldap_blocked) }
  let_it_be(:external_user) { create(:user, :external) }
  let_it_be(:unconfirmed_user) { create(:user, confirmed_at: nil) }
  let_it_be(:omniauth_user) { create(:omniauth_user) }
  let_it_be(:internal_user) { Users::Internal.alert_bot }
  let_it_be(:project_bot_user) { create(:user, :project_bot) }
  let_it_be(:service_account_user) { create(:user, :service_account) }

  before_all do
    root_group.add_owner(current_user)
  end

  subject(:finder) do
    described_class.new(current_user, resource)
  end

  describe '#execute' do
    context 'for SSO enforcement requirements' do
      let_it_be(:resource) { project }

      let_it_be_with_reload(:saml_provider) { create(:saml_provider, group: root_group, enforced_sso: true) }

      let_it_be(:user_with_group_saml_identity) do
        create(:user).tap do |user|
          create(:group_saml_identity, saml_provider: saml_provider, user: user)
        end
      end

      let_it_be(:blocked_user_with_group_saml_identity) do
        create(:user, :blocked).tap do |user|
          create(:group_saml_identity, saml_provider: saml_provider, user: user)
        end
      end

      let_it_be(:group_service_account) { create(:service_account, provisioned_by_group: root_group) }
      let_it_be(:blocked_group_service_account) { create(:service_account, :blocked, provisioned_by_group: root_group) }
      let_it_be(:another_group_service_account) { create(:service_account, provisioned_by_group: create(:group)) }

      let(:searchable_group_users_ordered_by_id_desc) do
        [
          user_with_group_saml_identity,
          group_service_account
        ].sort_by(&:id).reverse
      end

      let(:searchable_users_ordered_by_id_desc) do
        [
          current_user,
          regular_user,
          admin_user,
          external_user,
          unconfirmed_user,
          omniauth_user,
          service_account_user,
          *searchable_group_users_ordered_by_id_desc,
          another_group_service_account
        ].sort_by(&:id).reverse
      end

      before do
        stub_licensed_features(group_saml: true)
      end

      context 'when SSO enforcement is enabled' do
        it 'returns searchable users scoped for the resource and ordered by id descending' do
          expect(finder.execute).to eq(searchable_group_users_ordered_by_id_desc)
        end
      end

      context 'when SSO enforcement is disabled' do
        before do
          saml_provider.update!(enforced_sso: false)
        end

        it 'returns searchable users ordered by id descending' do
          expect(finder.execute).to eq(searchable_users_ordered_by_id_desc)
        end
      end
    end
  end
end
