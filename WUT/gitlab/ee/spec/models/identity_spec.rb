# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Identity, feature_category: :system_access do
  describe 'relations' do
    it { is_expected.to belong_to(:saml_provider) }
  end

  context 'with saml_provider' do
    before do
      stub_licensed_features(group_saml: true)
    end

    it 'allows user to have records with different groups' do
      _identity_one = create(:identity, provider: 'group_saml', saml_provider: create(:saml_provider))
      identity_two = create(:identity, provider: 'group_saml', saml_provider: create(:saml_provider))

      expect(identity_two).to be_valid
    end

    it "doesn't allow NameID/extern_uid to be blank" do
      identity = build(:identity, provider: 'group_saml', saml_provider: create(:saml_provider), extern_uid: "")

      expect(identity).not_to be_valid
      expect(identity.errors.full_messages.join)
      .to include("SAML NameID is missing from your SAML response. Please contact your administrator")
    end

    context 'with enforced_group_managed_accounts' do
      subject { build_stubbed(:identity, provider: 'group_saml', saml_provider: saml_provider, user: user) }

      let(:saml_provider) { build_stubbed(:saml_provider, :enforced_group_managed_accounts) }

      context 'when managing_group matches saml_provider group' do
        let(:user) { build_stubbed(:user, managing_group: saml_provider.group) }

        it { is_expected.to be_valid }
      end

      context 'when managing_group does not match provider group' do
        let(:user) { build_stubbed(:user, managing_group: Group.new) }

        it 'is not valid' do
          expect do
            subject.valid?
          end.to change { subject.errors[:base] }.to(['Group requires separate account'])
        end
      end
    end
  end

  describe 'after_destroy' do
    let!(:user) { create(:user) }
    let(:ldap_identity) do
      create(:identity, provider: 'ldapmain', extern_uid: 'uid=john smith,ou=people,dc=example,dc=com', user: user)
    end

    context 'when a user has admin role assigned' do
      before do
        create(:user_member_role, user: user, ldap: true)
      end

      it 'sets the ldap attributes of the role to false' do
        expect { ldap_identity.destroy! }.to change { user.reload.user_member_role.ldap? }
          .from(true).to(false)
      end
    end
  end
end
