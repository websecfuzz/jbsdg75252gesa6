# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::EE::Gitlab::Scim::Group::ReprovisioningService, feature_category: :system_access do
  describe '#execute' do
    let_it_be(:identity) { create(:scim_identity, active: false) }
    let_it_be(:group) { identity.group }
    let_it_be(:user) { identity.user }
    let_it_be(:saml_provider) do
      create(:saml_provider, group: group, default_membership_role: Gitlab::Access::DEVELOPER)
    end

    let(:service) { described_class.new(identity) }

    it 'activates scim identity' do
      service.execute

      expect(identity.active).to be true
    end

    it 'creates the member' do
      service.execute

      expect(group.members.pluck(:user_id)).to include(user.id)
    end

    it 'creates the member with the access level as specified in saml_provider' do
      service.execute

      access_level = group.member(user).access_level

      expect(access_level).to eq(Gitlab::Access::DEVELOPER)
    end

    context 'when a custom role is given for created group member', feature_category: :permissions do
      let(:member_role) { create(:member_role, namespace: group) }
      let!(:saml_provider) do
        create(:saml_provider, group: group,
          default_membership_role: member_role.base_access_level,
          member_role: member_role)
      end

      before do
        stub_licensed_features(custom_roles: true)
      end

      it 'sets the `member_role` of the member as specified in `saml_provider`' do
        service.execute

        expect(group.member(user).member_role).to eq(member_role)
      end
    end

    it 'does not change group membership when the user is already a member' do
      create(:group_member, group: group, user: user)

      expect { service.execute }.not_to change { group.members.count }
    end

    context 'with minimal access user' do
      before do
        stub_licensed_features(minimal_access_role: true)
        create(:group_member, group: group, user: user, access_level: ::Gitlab::Access::MINIMAL_ACCESS)
      end

      it 'does not change group membership when the user is already a member' do
        expect { service.execute }.not_to change { group.all_group_members.count }
      end
    end
  end
end
