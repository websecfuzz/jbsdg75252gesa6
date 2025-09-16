# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PersonalAccessTokenPolicy, feature_category: :permissions do
  subject { described_class.new(current_user, token) }

  let_it_be(:current_user) { create(:user) }

  context 'for enterprise user token revocation' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:group) { create(:group, :private) }
    let_it_be(:user) { create(:user) }
    let_it_be(:enterprise_user) { create(:enterprise_user, enterprise_group: group) }

    where(:group_member, :group_owner?, :saas?, :domain_verification?, :allowed) do
      ref(:user)      | false  | false  | false  | false
      ref(:user)      | false  | false  | true   | false
      ref(:user)      | false  | true   | false  | false
      ref(:user)      | false  | true   | true   | false
      ref(:user)      | true   | false  | false  | false
      ref(:user)      | true   | false  | true   | false
      ref(:user)      | true   | true   | false  | false
      ref(:user)      | true   | true   | true   | false

      ref(:enterprise_user)      | false  | false  | false  | false
      ref(:enterprise_user)      | false  | false  | true   | false
      ref(:enterprise_user)      | false  | true   | false  | false
      ref(:enterprise_user)      | false  | true   | true   | false
      ref(:enterprise_user)      | true   | false  | false  | false
      ref(:enterprise_user)      | true   | false  | true   | false
      ref(:enterprise_user)      | true   | true   | false  | false
      ref(:enterprise_user)      | true   | true   | true   | true
    end

    with_them do
      let(:token) { create(:personal_access_token, user: group_member) }

      context "for token revoke and rotate policy", saas: params[:saas?] do
        before do
          stub_licensed_features(
            domain_verification: domain_verification?
          )

          access_level = group_owner? ? :owner : :maintainer
          group.add_member(current_user, access_level)

          group.add_developer(group_member) # rubocop:disable RSpec/BeforeAllRoleAssignment -- Does not work in before_all
        end

        it { is_expected.to(allowed ? be_allowed(:revoke_token) : be_disallowed(:revoke_token)) }
        it { is_expected.to(allowed ? be_allowed(:rotate_token) : be_disallowed(:rotate_token)) }
      end
    end
  end

  context 'for service account token revocation' do
    let(:group) { create(:group) }
    let(:service_account) { create(:user, :service_account, provisioned_by_group: group) }
    let(:token) { create(:personal_access_token, user: service_account) }

    context "with owner", :saas do
      before do
        stub_licensed_features(domain_verification: true)
        group.add_owner(current_user)

        group.add_developer(service_account)
      end

      it { is_expected.to be_allowed(:revoke_token) }
    end

    context "with member", :saas do
      before do
        stub_licensed_features(domain_verification: true)
        group.add_member(current_user, :developer)

        group.add_developer(service_account)
      end

      it { is_expected.not_to be_allowed(:revoke_token) }
    end
  end
end
