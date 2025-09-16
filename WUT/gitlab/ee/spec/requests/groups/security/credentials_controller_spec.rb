# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::Security::CredentialsController, :saas, feature_category: :user_management do
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:enterprise_users) { create_list(:enterprise_user, 2, enterprise_group: group) }
  let_it_be(:service_accounts) { create_list(:service_account, 2, provisioned_by_group: group) }
  let_it_be(:owner) { enterprise_users.first }
  let_it_be(:maintainer) { enterprise_users.last }
  let_it_be(:group_id) { group.to_param }
  let_it_be(:personal_access_token) { create(:personal_access_token, user: maintainer) }
  let_it_be(:service_account_token) { create(:personal_access_token, user: service_accounts.first) }

  before do
    allow_next_instance_of(Gitlab::Auth::GroupSaml::SsoEnforcer) do |sso_enforcer|
      allow(sso_enforcer).to receive(:active_session?).and_return(true)
    end

    group.add_owner(owner)
    group.add_maintainer(maintainer)

    login_as(owner)
  end

  describe 'GET #index' do
    let(:filter) {}
    let(:owner_type) {}

    subject(:get_request) { get group_security_credentials_path(group_id: group_id.to_param, filter: filter, owner_type: owner_type) }

    context 'when `credentials_inventory` feature is licensed' do
      before do
        stub_licensed_features(credentials_inventory: true, group_saml: true)
      end

      context 'for a user with access to view credentials inventory' do
        it_behaves_like 'internal event tracking' do
          let(:event) { 'visit_authentication_credentials_inventory' }
          let(:user) { owner }
          let(:project) { nil }
          let(:namespace) { group }

          subject(:group_security_credentials_request) { get_request }
        end

        it 'responds with 200' do
          get_request

          expect(response).to have_gitlab_http_status(:ok)
        end

        context 'filtering by type of credential' do
          before do
            enterprise_users.each do |user|
              create(:personal_access_token, user: user)
            end
            service_accounts.each do |user|
              create(:personal_access_token, user: user)
            end
          end

          context 'no credential type specified' do
            let(:filter) { nil }

            it 'returns all personal access tokens' do
              get_request

              expected_tokens = PersonalAccessToken.where(user: enterprise_users + service_accounts)
              expect(assigns(:credentials)).to match_array(expected_tokens)
            end
          end

          context 'non-existent credential type specified' do
            let(:filter) { 'non_existent_credential_type' }

            it 'returns all personal access tokens' do
              get_request

              expected_tokens = PersonalAccessToken.where(user: enterprise_users + service_accounts)
              expect(assigns(:credentials)).to match_array(expected_tokens)
            end
          end

          context 'credential type specified as `personal_access_tokens`' do
            let(:filter) { 'personal_access_tokens' }

            it 'returns all personal access tokens' do
              get_request

              expected_tokens = PersonalAccessToken.where(user: enterprise_users + service_accounts)
              expect(assigns(:credentials)).to match_array(expected_tokens)
            end
          end

          context 'user scope' do
            it 'does not show the credentials of a user outside the group' do
              personal_access_token = create(:personal_access_token, user: create(:user))

              get_request

              expect(assigns(:credentials)).not_to include(personal_access_token)
            end

            it 'includes service account tokens in the scope' do
              get_request

              expect(assigns(:credentials)).to include(service_account_token)
            end
          end

          context 'credential type specified as `ssh_keys`' do
            let(:filter) { 'ssh_keys' }

            before do
              enterprise_users.each do |user|
                create(:personal_key, user: user)
              end
              service_accounts.each do |user|
                create(:personal_key, user: user)
              end
            end

            it 'filters by ssh keys' do
              get_request

              expect(assigns(:credentials)).to match_array(Key.regular_keys.where(user: enterprise_users + service_accounts))
            end
          end

          context 'credential type specified as `resource access tokens`' do
            let(:filter) { 'resource_access_tokens' }

            let_it_be(:subgroup) { create(:group, :private, parent: group) }
            let_it_be(:project) { create(:project, :private, group: subgroup) }
            let_it_be(:other_group) { create(:group, :private) }

            let_it_be(:group_bot) { create(:user, :project_bot, name: "Group bot", created_by_id: owner.id) }
            let_it_be(:subgroup_bot) { create(:user, :project_bot, name: "Subgroup bot", created_by_id: owner.id) }
            let_it_be(:project_bot) { create(:user, :project_bot, name: "Project bot", created_by_id: owner.id) }
            let_it_be(:nonmember_bot) { create(:user, :project_bot, name: "Non-member bot", created_by_id: owner.id) }

            let_it_be(:group_bot_token) do
              create(:personal_access_token, user: group_bot, scopes: %w[read_api])
            end

            let_it_be(:subgroup_bot_token) do
              create(:personal_access_token, user: subgroup_bot, scopes: %w[read_api])
            end

            let_it_be(:project_bot_token) do
              create(:personal_access_token, user: project_bot, scopes: %w[read_api])
            end

            let_it_be(:nonmember_bot_token) do
              create(:personal_access_token, user: nonmember_bot, scopes: %w[read_api])
            end

            before_all do
              group_bot.update!(bot_namespace: group)
              subgroup_bot.update!(bot_namespace: subgroup)
              project_bot.update!(bot_namespace: project.project_namespace)
              nonmember_bot.update!(bot_namespace: other_group)

              group.add_developer(group_bot)
              subgroup.add_developer(subgroup_bot)
              project.add_developer(project_bot)
              other_group.add_developer(nonmember_bot)
            end

            it 'filters resource access tokens for project bots that belong to the hierarchy' do
              get_request

              expect(assigns(:credentials)).to match_array([group_bot_token, subgroup_bot_token, project_bot_token])
            end
          end
        end

        context 'filtering by owner type' do
          before do
            enterprise_users.each do |user|
              create(:personal_access_token, user: user)
            end
            service_accounts.each do |user|
              create(:personal_access_token, user: user)
            end
          end

          context 'when owner_type is human' do
            let(:filter) { 'personal_access_tokens' }
            let(:owner_type) { 'human' }

            it 'returns only human user tokens' do
              get_request

              expected_tokens = PersonalAccessToken.where(user: enterprise_users)
              expect(assigns(:credentials)).to match_array(expected_tokens)
            end
          end

          context 'when owner_type is service_account' do
            let(:filter) { 'personal_access_tokens' }
            let(:owner_type) { 'service_account' }

            it 'returns only service account tokens' do
              get_request

              expected_tokens = PersonalAccessToken.where(user: service_accounts)
              expect(assigns(:credentials)).to match_array(expected_tokens)
            end
          end

          context 'when owner_type is not specified' do
            let(:filter) { 'personal_access_tokens' }
            let(:owner_type) { nil }

            it 'returns all tokens regardless of owner type' do
              get_request

              expected_tokens = PersonalAccessToken.where(user: enterprise_users + service_accounts)
              expect(assigns(:credentials)).to match_array(expected_tokens)
            end
          end
        end

        context 'for a user without access to view credentials inventory' do
          before do
            sign_in(maintainer)
          end

          it 'responds with 404' do
            get_request

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end
      end
    end

    context 'when `credentials_inventory` feature is unlicensed' do
      before do
        stub_licensed_features(credentials_inventory: false)
      end

      it 'returns 404' do
        get_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'DELETE #destroy' do
    let(:credentials_path) { group_security_credentials_path(filter: 'ssh_keys') }

    it_behaves_like 'credentials inventory delete SSH key', group_credentials_inventory: true
  end

  describe 'PUT #revoke' do
    it_behaves_like 'credentials inventory revoke project & group access tokens', group_credentials_inventory: true

    shared_examples_for 'responds with 404' do
      it do
        put revoke_group_security_credential_path(group_id: group_id.to_param, id: token_id)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    shared_examples_for 'displays the flash success message' do
      it do
        put revoke_group_security_credential_path(group_id: group_id.to_param, id: token_id)

        expect(response).to redirect_to(group_security_credentials_path)
        expect(flash[:notice]).to start_with 'Revoked personal access token '
      end
    end

    shared_examples_for 'displays the flash error message' do
      it do
        put revoke_group_security_credential_path(group_id: group_id.to_param, id: token_id)

        expect(response).to redirect_to(group_security_credentials_path)
        expect(flash[:alert]).to eql 'Not permitted to revoke'
      end
    end

    context 'when `credentials_inventory` feature is enabled', :saas do
      before do
        stub_licensed_features(credentials_inventory: true, group_saml: true, domain_verification: true)
      end

      context 'for a group with enterprise users' do
        context 'for a user with access to view credentials inventory' do
          context 'non-existent personal access token specified' do
            let(:token_id) { 999999999999999999999999999999999 }

            it_behaves_like 'responds with 404'
          end

          describe 'with an existing personal access token' do
            context 'personal access token is already revoked' do
              let_it_be(:token_id) { create(:personal_access_token, revoked: true, user: maintainer).id }

              it_behaves_like 'displays the flash success message'
            end

            context 'personal access token is already expired' do
              let_it_be(:token_id) { create(:personal_access_token, expires_at: 5.days.ago, user: maintainer).id }

              it_behaves_like 'displays the flash success message'
            end

            context 'does not have permissions to revoke the credential' do
              let_it_be(:token_id) { create(:personal_access_token, user: create(:user)).id }

              it_behaves_like 'responds with 404'
            end

            context 'personal access token is already revoked' do
              let_it_be(:token_id) { create(:personal_access_token, revoked: true, user: maintainer).id }

              it_behaves_like 'displays the flash success message'
            end

            context 'personal access token is already expired' do
              let_it_be(:token_id) { create(:personal_access_token, expires_at: 5.days.ago, user: maintainer).id }

              it_behaves_like 'displays the flash success message'
            end

            context 'personal access token is not revoked or expired' do
              let_it_be(:token_id) { personal_access_token.id }

              it_behaves_like 'displays the flash success message'

              it 'informs the token owner' do
                expect(CredentialsInventoryMailer).to receive_message_chain(:personal_access_token_revoked_email, :deliver_later)

                put revoke_group_security_credential_path(group_id: group_id.to_param, id: personal_access_token.id)
              end
            end

            context 'service account personal access token' do
              let_it_be(:token_id) { service_account_token.id }

              it_behaves_like 'displays the flash success message'

              it 'can revoke service account tokens' do
                expect { put revoke_group_security_credential_path(group_id: group_id.to_param, id: service_account_token.id) }
                  .to change { service_account_token.reload.revoked? }.from(false).to(true)
              end
            end
          end
        end

        context 'for a user without access to view credentials inventory' do
          let_it_be(:token_id) { create(:personal_access_token, user: owner).id }

          before do
            sign_in(maintainer)
          end

          it_behaves_like 'responds with 404'
        end
      end

      context 'for non-enterprise user tokens' do
        let_it_be(:token_id) { personal_access_token.id }
        let_it_be(:group_id) { create(:group).id }

        it 'responds with 404' do
          expect do
            put revoke_group_security_credential_path(group_id: group_id.to_param, id: token_id)
          end.to raise_error(ActionController::RoutingError)
        end
      end
    end

    context 'when `credentials_inventory` feature is disabled' do
      let_it_be(:token_id) { create(:personal_access_token, user: owner).id }

      before do
        stub_licensed_features(credentials_inventory: false)
      end

      it_behaves_like 'responds with 404'
    end
  end
end
