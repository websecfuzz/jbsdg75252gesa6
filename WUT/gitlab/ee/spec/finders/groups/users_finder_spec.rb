# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::UsersFinder, feature_category: :user_management do
  describe '#execute' do
    let_it_be(:group) { create(:group) }
    let_it_be(:other_group) { create(:group) }
    let_it_be(:saml_provider) { create(:saml_provider, group: group) }
    let_it_be(:other_saml_provider) { create(:saml_provider, group: other_group) }

    let_it_be(:saml_user1) { create(:user) }
    let_it_be(:saml_user2) { create(:user) }
    let_it_be(:service_account1) { create(:service_account, provisioned_by_group: group) }
    let_it_be(:service_account2) { create(:service_account, provisioned_by_group: group) }

    let_it_be(:saml_identity1) do
      create(:group_saml_identity, saml_provider: saml_provider, user: saml_user1)
    end

    let_it_be(:saml_identity2) do
      create(:group_saml_identity, saml_provider: saml_provider, user: saml_user2)
    end

    let_it_be(:other_saml_user) { create(:user) }

    let_it_be(:other_saml_identity) do
      create(:group_saml_identity, saml_provider: other_saml_provider, user: other_saml_user)
    end

    let_it_be(:other_service_account) { create(:service_account, provisioned_by_group: other_group) }

    subject(:finder) { described_class.new(saml_user1, group, params) }

    context 'when params includes both saml users and service accounts' do
      let(:params) { { include_saml_users: true, include_service_accounts: true } }

      it 'finds both saml users and service accounts' do
        expect(finder.execute).to match_array([saml_user1, saml_user2, service_account1, service_account2])
      end

      it 'orders by id descending' do
        expect(finder.execute).to eq([service_account2, service_account1, saml_user2, saml_user1])
      end
    end

    context 'when params includes only saml users' do
      let(:params) { { include_saml_users: true } }

      it 'finds only saml users' do
        expect(finder.execute).to match_array([saml_user1, saml_user2])
      end

      context 'when active param is true' do
        let(:params) { { active: true, include_saml_users: true } }

        before do
          saml_user2.block!
        end

        it 'includes only active users' do
          expect(finder.execute).to match_array([saml_user1])
        end
      end
    end

    context 'when params includes only service accounts' do
      let(:params) { { include_service_accounts: true } }

      it 'finds only service accounts' do
        expect(finder.execute).to match_array([service_account1, service_account2])
      end
    end

    context 'when params do not include either saml users or service accounts' do
      let(:params) { nil }

      it 'raises an argument error' do
        expect { finder.execute }
          .to raise_error(ArgumentError,
            format(
              _("At least one of %{params} must be true"),
              params: described_class::ALLOWED_FILTERS.join(', ')
            )
          )
      end
    end

    context 'when params are all false' do
      let(:params) { { include_saml_users: false, include_service_accounts: false } }

      it 'raises an argument error' do
        expect { finder.execute }
          .to raise_error(ArgumentError,
            format(
              _("At least one of %{params} must be true"),
              params: described_class::ALLOWED_FILTERS.join(', ')
            )
          )
      end
    end

    context 'when a group has no SAML providers, SAML users, or Service Accounts' do
      it 'returns no users' do
        group = create(:group)
        finder = described_class.new(saml_user1, group, { include_saml_users: true, include_service_accounts: true })

        expect(finder.execute).to be_empty
      end
    end
  end
end
