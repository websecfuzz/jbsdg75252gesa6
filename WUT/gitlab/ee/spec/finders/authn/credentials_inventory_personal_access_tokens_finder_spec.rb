# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authn::CredentialsInventoryPersonalAccessTokensFinder, :enable_admin_mode, feature_category: :system_access do
  using RSpec::Parameterized::TableSyntax

  before_all do
    freeze_time
  end

  after(:all) do
    unfreeze_time
  end

  describe '#execute' do
    shared_examples 'credentials_inventory_filters_and_sorting' do
      describe 'filters' do
        describe 'by state' do
          where(:by_state, :expected_tokens) do
            'active'   | [:active]
            'inactive' | [:expired, :revoked]
          end

          with_them do
            let(:params) do
              { users: enterprise_users_relation, impersonation: false, sort: 'expires_at_asc', state: by_state }
            end

            it 'returns tokens by state' do
              is_expected.to match_array(tokens.values_at(*expected_tokens))
            end
          end
        end

        describe 'by revoked state' do
          where(:by_revoked_state, :expected_tokens) do
            true  | [:revoked]
            false | [:active, :expired]
          end

          with_them do
            let(:params) do
              { users: enterprise_users_relation, impersonation: false, sort: 'expires_at_asc',
                revoked: by_revoked_state }
            end

            it 'returns tokens by revoked state' do
              is_expected.to match_array(tokens.values_at(*expected_tokens))
            end
          end
        end

        describe 'by created date' do
          before do
            tokens[:active].update!(created_at: 5.days.ago)
          end

          describe 'by created before' do
            where(:by_created_before, :expected_tokens) do
              6.days.ago      | []
              2.days.ago      | [:active]
              2.days.from_now | [:active, :expired, :revoked]
            end

            with_them do
              let(:params) do
                { users: enterprise_users_relation, impersonation: false, sort: 'expires_at_asc',
                  created_before: by_created_before }
              end

              it 'returns tokens by created before' do
                is_expected.to match_array(tokens.values_at(*expected_tokens))
              end
            end
          end

          describe 'by created after' do
            where(:by_created_after, :expected_tokens) do
              6.days.ago      | [:active, :expired, :revoked]
              2.days.ago      | [:expired, :revoked]
              2.days.from_now | []
            end

            with_them do
              let(:params) do
                { users: enterprise_users_relation, impersonation: false, sort: 'expires_at_asc',
                  created_after: by_created_after }
              end

              it 'returns tokens by created before' do
                is_expected.to match_array(tokens.values_at(*expected_tokens))
              end
            end
          end
        end

        describe 'by expires before' do
          where(:by_expires_before, :expected_tokens) do
            2.days.ago       | []
            29.days.from_now | [:expired]
            31.days.from_now | [:active, :expired, :revoked]
          end

          with_them do
            let(:params) do
              { users: enterprise_users_relation, impersonation: false, sort: 'expires_at_asc',
                expires_before: by_expires_before }
            end

            it 'returns tokens by expires before' do
              is_expected.to match_array(tokens.values_at(*expected_tokens))
            end
          end
        end

        describe 'by expires after' do
          where(:by_expires_after, :expected_tokens) do
            2.days.ago       | [:active, :expired, :revoked]
            30.days.from_now | [:active, :revoked]
            31.days.from_now | []
          end

          with_them do
            let(:params) do
              { users: enterprise_users_relation, impersonation: false, sort: 'expires_at_asc',
                expires_after: by_expires_after }
            end

            it 'returns tokens by expires after' do
              is_expected.to match_array(tokens.values_at(*expected_tokens))
            end
          end
        end

        describe 'by last used date' do
          before do
            PersonalAccessToken.update_all(last_used_at: Time.now)
            tokens[:active].update!(last_used_at: 5.days.ago)
          end

          describe 'by last used before' do
            where(:by_last_used_before, :expected_tokens) do
              6.days.ago      | []
              2.days.ago      | [:active]
              2.days.from_now | [:active, :expired, :revoked]
            end

            with_them do
              let(:params) do
                { users: enterprise_users_relation, impersonation: false, sort: 'expires_at_asc',
                  last_used_before: by_last_used_before }
              end

              it 'returns tokens by last used before' do
                is_expected.to match_array(tokens.values_at(*expected_tokens))
              end
            end
          end

          describe 'by last used after' do
            where(:by_last_used_after, :expected_tokens) do
              6.days.ago      | [:active, :expired, :revoked]
              2.days.ago      | [:expired, :revoked]
              2.days.from_now | []
            end

            with_them do
              let(:params) do
                { users: enterprise_users_relation, impersonation: false, sort: 'expires_at_asc',
                  last_used_after: by_last_used_after }
              end

              it 'returns tokens by last used after' do
                is_expected.to match_array(tokens.values_at(*expected_tokens))
              end
            end
          end
        end

        describe 'by search' do
          where(:by_search, :expected_tokens) do
            nil      | [:active, :expired, :revoked]
            'my_pat' | [:active]
            'other'  | []
          end

          with_them do
            let(:params) do
              { users: enterprise_users_relation, impersonation: false, sort: 'expires_at_asc', search: by_search }
            end

            it 'returns tokens by search' do
              is_expected.to match_array(tokens.values_at(*expected_tokens))
            end
          end
        end
      end

      describe 'sort' do
        where(:sort, :expected_tokens) do
          'last_used_desc' | [:revoked, :expired, :active]
          'created_date' | [:active, :expired, :revoked]
          'id_asc'       | [:active, :expired, :revoked]
          'testing_desc' | [:expired, :revoked, :active] # default { expires_at: :asc, id: :desc }
        end

        with_them do
          let(:params) { { users: enterprise_users_relation, impersonation: false, sort: sort } }

          it 'returns ordered tokens' do
            expect(pat_finder.map(&:id)).to eq(tokens.values_at(*expected_tokens).map(&:id))
          end
        end
      end
    end

    shared_examples 'uses the ::PersonalAccessTokensFinder base execute' do
      it 'does not use the InOperatorOptimization::QueryBuilder module' do
        expect(::Gitlab::Pagination::Keyset::InOperatorOptimization::QueryBuilder)
          .not_to receive(:new).and_call_original

        pat_finder
      end

      it 'uses the standard PersonalAccessTokensFinder' do
        expect_next_instance_of(::PersonalAccessTokensFinder) do |original_pat_finder|
          expect(original_pat_finder).to receive(:execute).and_call_original
        end

        pat_finder
      end
    end

    shared_examples 'uses the ::Authn::CredentialsInventoryPersonalAccessTokensFinder execute' do
      it 'uses the InOperatorOptimization::QueryBuilder module' do
        expect(::Gitlab::Pagination::Keyset::InOperatorOptimization::QueryBuilder)
          .to receive(:new).and_call_original

        pat_finder
      end

      it_behaves_like 'credentials_inventory_filters_and_sorting'
    end

    describe '#optimized_execute_for_credentials_inventory' do
      let_it_be(:top_level_group_owner) { create(:user, name: 'Wally West') }
      let(:non_enterprise_users_relation) { User.none }
      let_it_be(:group) { create(:group, owners: top_level_group_owner) }
      let_it_be(:enterprise_user) do
        create(:user, developer_of: group).tap do |user|
          user.user_detail.update!(enterprise_group_id: group.id)
        end
      end

      let_it_be(:other_user) { create(:user, developer_of: group) }
      let_it_be(:project_bot) { create(:user, :project_bot) }

      let_it_be(:tokens) do
        {
          active: create(:personal_access_token, user: enterprise_user, name: 'my_pat_1'),
          active_other: create(:personal_access_token, user: other_user, name: 'my_pat_2'),
          expired: create(:personal_access_token, :expired, user: enterprise_user),
          revoked: create(:personal_access_token, :revoked, user: enterprise_user),
          active_impersonation: create(:personal_access_token, :impersonation, user: enterprise_user),
          expired_impersonation: create(:personal_access_token, :expired, :impersonation, user: enterprise_user),
          revoked_impersonation: create(:personal_access_token, :revoked, :impersonation, user: enterprise_user),
          bot: create(:personal_access_token, user: project_bot)
        }
      end

      let(:tokens_keys) { tokens.keys }
      let(:params) { { users: enterprise_users_relation, impersonation: false, sort: 'expires_at_asc' } }

      let(:current_user) { top_level_group_owner }

      subject(:pat_finder) do
        described_class.new(default_params.merge(params), current_user).execute
      end

      describe 'when on the `/groups` credentials inventory', :saas do
        let(:default_params) { { owner_type: 'human', group: group } }

        context 'when the credentials_inventory_pat_finder FF is enabled' do
          let(:enterprise_users_relation) { group.enterprise_user_details }

          before do
            stub_feature_flags(credentials_inventory_pat_finder: true)
          end

          it_behaves_like 'uses the ::Authn::CredentialsInventoryPersonalAccessTokensFinder execute'
        end

        context 'when the credentials_inventory_pat_finder FF is disabled' do
          let(:enterprise_users_relation) { group.enterprise_users }

          before do
            stub_feature_flags(credentials_inventory_pat_finder: false)
          end

          it_behaves_like 'uses the ::PersonalAccessTokensFinder base execute'
        end
      end

      describe 'when on the `/admin` credentials inventory' do
        let(:current_user) { create(:admin) }
        let(:default_params) { { owner_type: 'human' } }

        # Exclude non-enterprise users for this test to use the groups shared_example
        let(:enterprise_users_relation) do
          User.where(id: [enterprise_user.id])
        end

        context 'when the credentials_inventory_pat_finder FF is enabled' do
          before do
            stub_feature_flags(credentials_inventory_pat_finder: true)
          end

          it_behaves_like 'uses the ::Authn::CredentialsInventoryPersonalAccessTokensFinder execute'
        end

        context 'when the credentials_inventory_pat_finder FF is disabled' do
          before do
            stub_feature_flags(credentials_inventory_pat_finder: false)
          end

          it_behaves_like 'uses the ::PersonalAccessTokensFinder base execute'
        end
      end
    end
  end
end
