# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Manage::Groups, :aggregate_failures, feature_category: :system_access do
  include Auth::DpopTokenHelper

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:personal_access_token) { create(:personal_access_token, user: current_user, scopes: [:api]) }

  let(:get_request) do
    get(api(path, personal_access_token: personal_access_token))
  end

  let(:delete_request) do
    delete(api(path, personal_access_token: personal_access_token))
  end

  before_all do
    group.update!(require_dpop_for_manage_api_endpoints: false)
    group.add_owner(current_user)
  end

  shared_examples 'a manage groups GET endpoint' do
    context "when feature flag is disabled" do
      before do
        stub_feature_flags(manage_pat_by_group_owners_ready: false)
      end

      it 'returns 404 not found' do
        get_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when unauthorized user' do
      let_it_be(:unauthorized_user) { create(:user) }
      let_it_be(:personal_access_token) { create(:personal_access_token, user: unauthorized_user, scopes: [:api]) }

      it 'returns 403 for unauthorized user' do
        get(api(path, personal_access_token: personal_access_token), headers: dpop_headers_for(unauthorized_user))

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  shared_examples 'a /manage/PAT GET endpoint using the credentials inventory PAT finder' do
    context 'when the :credentials_inventory_pat_finder is enabled' do
      before do
        stub_feature_flags(credentials_inventory_pat_finder: true)
      end

      it 'uses the InOperatorOptimization::QueryBuilder module' do
        expect(::Gitlab::Pagination::Keyset::InOperatorOptimization::QueryBuilder)
          .to receive(:new).and_call_original

        get_request
      end
    end

    context 'when the :credentials_inventory_pat_finder is disabled' do
      before do
        stub_feature_flags(credentials_inventory_pat_finder: false)
      end

      it 'does not use the InOperatorOptimization::QueryBuilder module' do
        expect(::Gitlab::Pagination::Keyset::InOperatorOptimization::QueryBuilder)
          .not_to receive(:new).and_call_original

        get_request
      end

      it 'uses the standard PersonalAccessTokensFinder' do
        expect_next_instance_of(::PersonalAccessTokensFinder) do |original_pat_finder|
          expect(original_pat_finder).to receive(:execute).and_call_original
        end

        get_request
      end
    end
  end

  shared_examples 'feature is not available to non saas versions' do |request_type|
    context 'when it is self-managed instance', saas: false do
      it "returns not found error" do
        send(request_type)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  shared_examples 'forbidden action for delete_request' do |delete_type|
    it "returns forbidden" do
      delete_request

      expect(response).to have_gitlab_http_status(:forbidden)

      expect(token.reload).not_to be_revoked if delete_type == :token
    end
  end

  shared_examples 'rotate token endpoint' do |token_type|
    context 'when current user is an administrator' do
      let_it_be(:personal_access_token) { create(:personal_access_token, user: create(:admin), scopes: [:api]) }

      context 'when admin mode enabled', :enable_admin_mode do
        it "rotates the token" do
          rotate_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['token']).not_to eq(token.token)
          expect(json_response['expires_at']).to eq((Time.zone.today + 1.week).to_s)
        end
      end
    end

    context 'when token does not belong to the group' do
      let_it_be(:other_group) { create(:group) }
      let_it_be(:path) { "/groups/#{other_group.id}/manage/#{token_type}/#{token.id}/rotate" }

      before_all do
        other_group.update!(require_dpop_for_manage_api_endpoints: false)
      end

      context 'when current user is owner of other group' do
        before_all do
          other_group.add_owner(current_user)
        end

        it "returns forbidden" do
          rotate_request

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'when current user is an administrator' do
        let_it_be(:personal_access_token) { create(:personal_access_token, user: create(:admin), scopes: [:api]) }

        context 'when admin mode enabled', :enable_admin_mode do
          it "returns forbidden" do
            rotate_request

            expect(response).to have_gitlab_http_status(:forbidden)
          end
        end
      end
    end

    context 'when token does not exist' do
      let_it_be(:path) { "/groups/#{group.id}/manage/#{token_type}/#{non_existing_record_id}/rotate" }

      it 'returns 404 for non-existing token' do
        rotate_request

        expect(response).to have_gitlab_http_status(:not_found)
        expect(json_response['message']).to eq('404 Not found')
      end
    end

    context 'when expiry is defined' do
      it "rotates user token and sets expires_at", :freeze_time do
        expiry_date = Time.zone.today + 1.month

        post(api(path, personal_access_token: personal_access_token), params: { expires_at: expiry_date })

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['token']).not_to eq(token.token)
        expect(json_response['expires_at']).to eq(expiry_date.to_s)
      end
    end

    context 'when current_user user is not a group owner' do
      let_it_be(:regular_user) { create(:user) }
      let_it_be(:personal_access_token) { create(:personal_access_token, user: regular_user) }

      before_all do
        group.add_maintainer(regular_user)
      end

      it "returns forbidden" do
        rotate_request

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe 'GET /groups/:id/manage/personal_access_tokens' do
    let_it_be(:path) { "/groups/#{group.id}/manage/personal_access_tokens" }

    let_it_be(:user) { create(:enterprise_user, enterprise_group: group) }

    let_it_be(:active_token1) { create(:personal_access_token, user: user, scopes: [:api]) }
    let_it_be(:active_token2) { create(:personal_access_token, user: user, scopes: [:api]) }
    let_it_be(:expired_token1) { create(:personal_access_token, user: user, expires_at: 1.year.ago) }
    let_it_be(:expired_token2) { create(:personal_access_token, user: user, expires_at: 1.year.ago) }
    let_it_be(:revoked_token1) { create(:personal_access_token, user: user, revoked: true) }
    let_it_be(:revoked_token2) { create(:personal_access_token, user: user, revoked: true) }

    let_it_be(:created_2_days_ago_token) { create(:personal_access_token, user: user, created_at: 2.days.ago) }
    let_it_be(:named_token) { create(:personal_access_token, user: user,  name: 'test_1') }
    let_it_be(:last_used_2_days_ago_token) { create(:personal_access_token, user: user, last_used_at: 2.days.ago) }
    let_it_be(:last_used_2_months_ago_token) do
      create(:personal_access_token, user: user, last_used_at: 2.months.ago)
    end

    let_it_be(:created_at_asc) do
      [
        created_2_days_ago_token,
        active_token1,
        active_token2,
        expired_token1,
        expired_token2,
        revoked_token1,
        revoked_token2,
        named_token,
        last_used_2_days_ago_token,
        last_used_2_months_ago_token
      ]
    end

    let_it_be(:non_enterprise_user) { create(:user) }
    # Token which should not be returned in any responses
    let_it_be(:non_enterprise_token) { create(:personal_access_token, user: non_enterprise_user, scopes: [:api]) }

    it_behaves_like 'feature is not available to non saas versions', "get_request"

    context 'when saas', :saas do
      it_behaves_like 'an access token GET API with access token params'

      it_behaves_like 'a manage groups GET endpoint'

      it_behaves_like 'a /manage/PAT GET endpoint using the credentials inventory PAT finder'

      it 'returns 404 for non-existing group' do
        get(api(
          "/groups/#{non_existing_record_id}/manage/personal_access_tokens",
          personal_access_token: personal_access_token
        ))

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'DELETE /groups/:id/manage/personal_access_tokens/:id' do
    let_it_be(:enterprise_user) { create(:enterprise_user, enterprise_group: group) }
    let_it_be(:token) { create(:personal_access_token, user: enterprise_user) }
    let_it_be(:path) { "/groups/#{group.id}/manage/personal_access_tokens/#{token.id}" }

    before do
      stub_licensed_features(domain_verification: true)
    end

    it_behaves_like 'feature is not available to non saas versions', "delete_request"

    context 'when saas', :saas do
      it 'returns 404 for non-existing group' do
        get(api(
          "/groups/#{non_existing_record_id}/manage/personal_access_tokens/#{token.id}",
          personal_access_token: personal_access_token
        ), headers: dpop_headers_for(current_user))

        expect(response).to have_gitlab_http_status(:not_found)
      end

      context 'when current user is a top level group owner' do
        let_it_be(:personal_access_token) { create(:personal_access_token, user: current_user) }
        let_it_be(:owner_token) { create(:personal_access_token, user: current_user) }
        let_it_be(:owner_token_path) { "/groups/#{group.id}/manage/personal_access_tokens/#{owner_token.id}" }
        let_it_be(:admin_read_only_token) do
          create(:personal_access_token, scopes: ['read_repository'], user: current_user)
        end

        it "revokes the personal access token for the other user" do
          delete api(path, personal_access_token: personal_access_token)

          expect(response).to have_gitlab_http_status(:no_content)
          expect(token.reload).to be_revoked
        end

        it 'fails to revoke a different user token using a readonly scope' do
          delete api(path, personal_access_token: admin_read_only_token)

          expect(token.reload).not_to be_revoked
        end

        context 'when token belongs to non enterprise user' do
          let_it_be(:regular_user) { create(:user) }
          let_it_be(:regular_user_token) { create(:personal_access_token, user: regular_user) }
          let_it_be(:path) { "/groups/#{group.id}/manage/personal_access_tokens/#{regular_user_token.id}" }

          it_behaves_like "forbidden action for delete_request", "token"
        end

        context 'when token does not belong to the group' do
          let_it_be(:other_group) { create(:group) }
          let_it_be(:path) { "/groups/#{other_group.id}/manage/personal_access_tokens/#{token.id}" }

          before_all do
            other_group.update!(require_dpop_for_manage_api_endpoints: false)
            other_group.add_owner(current_user)
          end

          it_behaves_like "forbidden action for delete_request", "token"
        end
      end

      context 'when user is not a top level group owner' do
        let_it_be(:regular_user) { create(:user) }
        let_it_be(:personal_access_token) { create(:personal_access_token, user: regular_user) }
        let_it_be(:subgroup) { create(:group, parent: group) }

        before_all do
          group.add_maintainer(regular_user)
          subgroup.add_owner(regular_user)
        end

        it_behaves_like "forbidden action for delete_request", "token"
      end

      context 'when current user is an administrator' do
        let_it_be(:personal_access_token) { create(:personal_access_token, user: create(:admin), scopes: [:api]) }

        context 'when admin mode enabled', :enable_admin_mode do
          it "revokes the personal access token for the other user" do
            delete api(path, personal_access_token: personal_access_token)

            expect(response).to have_gitlab_http_status(:no_content)
            expect(token.reload.revoked?).to be true
          end
        end

        context 'when admin mode not enabled' do
          it_behaves_like "forbidden action for delete_request", "token"
        end
      end
    end
  end

  describe "DELETE /groups/:id/manage/resource_access_tokens/:token_id" do
    let_it_be(:project_bot) { create(:user, :project_bot, bot_namespace: group) }
    let_it_be(:token) { create(:personal_access_token, user: project_bot) }
    let(:path) { "/groups/#{group.id}/manage/resource_access_tokens/#{token.id}" }
    let(:revoke_request) do
      delete api(path, personal_access_token: personal_access_token)
    end

    before_all do
      group.add_maintainer(project_bot)
    end

    it_behaves_like 'feature is not available to non saas versions', "delete_request"

    context 'when saas', :saas do
      context "when the user has valid permissions" do
        let_it_be(:personal_access_token) { create(:personal_access_token, user: current_user) }

        it "revokes the resources access token" do
          revoke_request

          expect(response).to have_gitlab_http_status(:no_content)
          expect(token.reload).to be_revoked
          expect(User.exists?(project_bot.id)).to be_truthy
        end

        context "when attempting to delete a token that does not belong to the specified group" do
          let_it_be(:other_group) { create(:group) }
          let_it_be(:path) { "/groups/#{other_group.id}/manage/resource_access_tokens/#{token.id}" }

          before_all do
            other_group.update!(require_dpop_for_manage_api_endpoints: false)
            other_group.add_owner(current_user)
          end

          it "returns bad request and not able to find the bot user as member of group" do
            revoke_request

            expect(response).to have_gitlab_http_status(:forbidden)
            expect(json_response['message']).to eq("403 Forbidden - Cannot access resource access token: " \
              "Token belongs to a resource outside group's hierarchy")
          end
        end

        context 'when token belongs to non bot user' do
          let_it_be(:regular_user) { create(:user) }
          let_it_be(:regular_user_token) { create(:personal_access_token, user: regular_user) }
          let_it_be(:path) { "/groups/#{group.id}/manage/resource_access_tokens/#{regular_user_token.id}" }

          it_behaves_like "forbidden action for delete_request", "token"
        end
      end

      context 'when token belongs to a project which belongs to group' do
        let_it_be(:project) { create(:project, namespace: group) }
        let_it_be(:project_bot) do
          create(:user, :project_bot, bot_namespace: project.project_namespace, developer_of: project)
        end

        let_it_be(:token) { create(:personal_access_token, user: project_bot) }
        let_it_be(:path) { "/groups/#{group.id}/manage/resource_access_tokens/#{token.id}" }

        it 'revokes token' do
          revoke_request

          expect(response).to have_gitlab_http_status(:no_content)
          expect(token.reload).to be_revoked
          expect(User.exists?(project_bot.id)).to be_truthy
        end
      end

      context 'when token belongs to a sub group' do
        let_it_be(:sub_group) { create(:group, parent: group) }
        let_it_be(:project_bot) do
          create(:user, :project_bot, bot_namespace: sub_group, developer_of: sub_group)
        end

        let_it_be(:token) { create(:personal_access_token, user: project_bot) }
        let_it_be(:path) { "/groups/#{group.id}/manage/resource_access_tokens/#{token.id}" }

        it 'revokes token' do
          revoke_request

          expect(response).to have_gitlab_http_status(:no_content)
          expect(token.reload).to be_revoked
          expect(User.exists?(project_bot.id)).to be_truthy
        end
      end

      context 'when token belongs to an unrelated project' do
        let_it_be(:project) { create(:project, namespace: create(:group)) }
        let_it_be(:project_bot) do
          create(:user, :project_bot, bot_namespace: project.project_namespace, developer_of: project)
        end

        let_it_be(:token) { create(:personal_access_token, user: project_bot) }
        let_it_be(:path) { "/groups/#{group.id}/manage/resource_access_tokens/#{token.id}" }

        it_behaves_like "forbidden action for delete_request", "token"
      end

      context "when the user does not have valid permissions" do
        let_it_be(:regular_user) { create(:user) }
        let_it_be(:personal_access_token) { create(:personal_access_token, user: regular_user) }

        before_all do
          group.add_maintainer(regular_user)
        end

        it_behaves_like "forbidden action for delete_request", "token"
      end
    end
  end

  describe "DELETE /groups/:id/manage/ssh_keys/:key_id" do
    let(:enterprise_user) { create(:enterprise_user, enterprise_group: group) }
    let(:ssh_key) { create(:personal_key, user: enterprise_user) }
    let(:path) { "/groups/#{group.id}/manage/ssh_keys/#{ssh_key.id}" }

    it_behaves_like 'feature is not available to non saas versions', "delete_request"

    context 'when saas', :saas do
      it 'returns 404 for non-existing group' do
        delete api("/group/#{non_existing_record_id}/manage/ssh_keys/#{ssh_key.id}")
        expect(response).to have_gitlab_http_status(:not_found)
      end

      context 'when authorized' do
        let_it_be(:personal_access_token) { create(:personal_access_token, user: current_user) }

        it 'deletes existing key' do
          enterprise_user.keys << ssh_key

          expect do
            delete api(path, personal_access_token: personal_access_token)

            expect(response).to have_gitlab_http_status(:no_content)
          end.to change { enterprise_user.keys.count }.by(-1)
        end

        it 'returns 404 error if key not found' do
          delete api("/groups/#{group.id}/manage/ssh_keys/#{non_existing_record_id}",
            personal_access_token: personal_access_token)
          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response['message']).to eq('404 Key Not Found')
        end

        context 'when key does not belong to enterprise user' do
          let_it_be(:regular_user) { create(:user) }
          let_it_be(:ssh_key) { create(:personal_key, user: regular_user) }

          before_all do
            create(:enterprise_user, enterprise_group: group)
            group.add_developer(regular_user)
            regular_user.keys << ssh_key
          end

          it "returns not found error" do
            delete_request

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end

        context 'when key belongs to a user from subgroup' do
          let(:subgroup) { create(:group, parent: group) }
          let(:enterprise_user) { create(:enterprise_user, enterprise_group: group) }
          let(:ssh_key) { create(:personal_key, user: enterprise_user) }

          before do
            subgroup.add_maintainer(enterprise_user)
          end

          it "deletes the ssh key" do
            enterprise_user.keys << ssh_key

            expect do
              delete api(path, personal_access_token: personal_access_token)

              expect(response).to have_gitlab_http_status(:no_content)
            end.to change { enterprise_user.keys.count }.by(-1)
          end
        end
      end

      context 'when unauthorized' do
        let_it_be(:regular_user) { create(:user) }
        let_it_be(:personal_access_token) { create(:personal_access_token, user: regular_user) }

        before_all do
          group.add_maintainer(regular_user)
        end

        it_behaves_like "forbidden action for delete_request"
      end
    end
  end

  describe 'POST /groups/:id/manage/personal_access_tokens/:id/rotate' do
    let_it_be(:enterprise_user) { create(:enterprise_user, enterprise_group: group) }
    let_it_be(:token) { create(:personal_access_token, user: enterprise_user) }
    let_it_be(:path) { "/groups/#{group.id}/manage/personal_access_tokens/#{token.id}/rotate" }
    let(:rotate_request) do
      post(api(path, personal_access_token: personal_access_token))
    end

    before do
      stub_licensed_features(domain_verification: true)
    end

    it_behaves_like 'feature is not available to non saas versions', "rotate_request"

    context 'when saas', :saas do
      before do
        stub_licensed_features(domain_verification: true)
      end

      it 'returns 404 for non-existing group' do
        post(api("/groups/#{non_existing_record_id}/manage/personal_access_tokens/#{token.id}/rotate",
          personal_access_token: personal_access_token))

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it 'rotates token of an enterprise user' do
        rotate_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['token']).not_to eq(token.token)
        expect(json_response['expires_at']).to eq((Time.zone.today + 1.week).to_s)
      end

      context 'when token user is not an enterprise user' do
        let_it_be(:regular_user) { create(:user) }
        let_it_be(:regular_user_token) { create(:personal_access_token, user: regular_user) }
        let_it_be(:path) { "/groups/#{group.id}/manage/personal_access_tokens/#{regular_user_token.id}/rotate" }

        before_all do
          group.add_developer(regular_user)
        end

        it "returns forbidden" do
          rotate_request

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      it_behaves_like "rotate token endpoint", "personal_access_tokens"
    end
  end

  describe 'POST /groups/:id/manage/resource_access_tokens/:id/rotate' do
    let_it_be(:project_bot) { create(:user, :project_bot, bot_namespace: group) }
    let_it_be(:token) { create(:personal_access_token, user: project_bot) }
    let_it_be(:path) { "/groups/#{group.id}/manage/resource_access_tokens/#{token.id}/rotate" }

    let(:rotate_request) do
      post(api(path, personal_access_token: personal_access_token))
    end

    it_behaves_like 'feature is not available to non saas versions', "rotate_request"

    context 'when saas', :saas do
      before_all do
        group.add_developer(project_bot)
      end

      it 'returns 404 for non-existing group' do
        post(api("/groups/#{non_existing_record_id}/manage/resource_access_tokens/#{token.id}/rotate",
          personal_access_token: personal_access_token))

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it 'rotates token of a bot' do
        rotate_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['token']).not_to eq(token.token)
        expect(json_response['expires_at']).to eq((Time.zone.today + 1.week).to_s)
      end

      context 'when token user is not a bot user' do
        let_it_be(:regular_user) { create(:user) }
        let_it_be(:regular_user_token) { create(:personal_access_token, user: regular_user) }
        let_it_be(:path) { "/groups/#{group.id}/manage/resource_access_tokens/#{regular_user_token.id}/rotate" }

        before_all do
          group.add_developer(regular_user)
        end

        it "returns forbidden" do
          rotate_request
          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'when rotate service throws error' do
        before do
          allow_next_instance_of(::GroupAccessTokens::RotateService) do |instance|
            allow(instance).to receive(:execute).and_return(ServiceResponse.error(message: "error"))
          end
        end

        it "returns bad_request" do
          rotate_request

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end

      context 'when token belongs to a project related to group' do
        let_it_be(:project) { create(:project, namespace: group) }
        let_it_be(:project_bot) do
          create(:user, :project_bot, bot_namespace: project.project_namespace, developer_of: project)
        end

        let_it_be(:token) { create(:personal_access_token, user: project_bot) }
        let_it_be(:path) { "/groups/#{group.id}/manage/resource_access_tokens/#{token.id}/rotate" }

        it 'rotates token' do
          rotate_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['token']).not_to eq(token.token)
        end
      end

      context 'when token belongs to a sub group' do
        let_it_be(:sub_group) { create(:group, parent: group) }
        let_it_be(:project_bot) do
          create(:user, :project_bot, bot_namespace: sub_group, developer_of: sub_group)
        end

        let_it_be(:token) { create(:personal_access_token, user: project_bot) }
        let_it_be(:path) { "/groups/#{group.id}/manage/resource_access_tokens/#{token.id}/rotate" }

        it 'rotates token' do
          rotate_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['token']).not_to eq(token.token)
        end
      end

      context 'when token belongs to an unrelated project' do
        let_it_be(:project) { create(:project, namespace: create(:group)) }
        let_it_be(:project_bot) do
          create(:user, :project_bot, bot_namespace: project.project_namespace, developer_of: project)
        end

        let_it_be(:token) { create(:personal_access_token, user: project_bot) }
        let_it_be(:path) { "/groups/#{group.id}/manage/resource_access_tokens/#{token.id}/rotate" }

        it 'throws forbidden error' do
          rotate_request

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      it_behaves_like "rotate token endpoint", "resource_access_tokens"
    end
  end

  describe 'GET /groups/:id/manage/resource_access_tokens' do
    let_it_be(:path) { "/groups/#{group.id}/manage/resource_access_tokens" }

    let_it_be(:group_bot) { create(:user, :project_bot, bot_namespace: group, developer_of: group) }
    let_it_be(:project) { create(:project, namespace: group) }
    let_it_be(:project_bot) do
      create(:user, :project_bot, bot_namespace: project.project_namespace, developer_of: project)
    end

    let_it_be(:active_token1) { create(:personal_access_token, user: project_bot) }
    let_it_be(:active_token2) { create(:personal_access_token, user: group_bot) }
    let_it_be(:expired_token1) { create(:personal_access_token, user: group_bot, expires_at: 1.year.ago) }
    let_it_be(:expired_token2) { create(:personal_access_token, user: group_bot, expires_at: 1.year.ago) }
    let_it_be(:revoked_token1) { create(:personal_access_token, user: group_bot, revoked: true) }
    let_it_be(:revoked_token2) { create(:personal_access_token, user: group_bot, revoked: true) }
    let_it_be(:created_2_days_ago_token) { create(:personal_access_token, user: project_bot, created_at: 2.days.ago) }
    let_it_be(:named_token) { create(:personal_access_token, user: group_bot, name: "Test token") }
    let_it_be(:last_used_2_days_ago_token) { create(:personal_access_token, user: group_bot, last_used_at: 2.days.ago) }
    let_it_be(:last_used_2_months_ago_token) do
      create(:personal_access_token, user: group_bot, last_used_at: 2.months.ago)
    end

    let_it_be(:created_at_asc) do
      [
        created_2_days_ago_token,
        active_token1,
        active_token2,
        expired_token1,
        expired_token2,
        revoked_token1,
        revoked_token2,
        named_token,
        last_used_2_days_ago_token,
        last_used_2_months_ago_token
      ]
    end

    let_it_be(:other_group_bot) { create(:user, :project_bot, bot_namespace: create(:group)) }

    # Tokens which should not be returned in any responses
    let_it_be(:excluded_token1) { create(:personal_access_token, user: current_user) }
    let_it_be(:excluded_token2) { create(:personal_access_token, user: create(:user, :service_account)) }
    let_it_be(:excluded_token3) { create(:personal_access_token, user: other_group_bot) }

    it_behaves_like 'feature is not available to non saas versions', "get_request"

    context 'when saas', :saas do
      it_behaves_like 'an access token GET API with access token params'
      it_behaves_like 'a manage groups GET endpoint'

      it 'returns 404 for non-existing group' do
        get(api(
          "/groups/#{non_existing_record_id}/manage/resource_access_tokens",
          personal_access_token: personal_access_token
        ), headers: dpop_headers_for(current_user))

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it 'returns the expected response for group tokens' do
        get api(path, personal_access_token: personal_access_token), params: { sort: 'created_at_desc' },
          headers: dpop_headers_for(current_user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('public_api/v4/resource_access_tokens')
        expect(json_response[0]['id']).to eq(last_used_2_months_ago_token.id)
        expect(json_response[0]['resource_type']).to eq('group')
        expect(json_response[0]['resource_id']).to eq(group.id)
      end

      it 'returns the expected response for project tokens' do
        get(api(path, personal_access_token: personal_access_token), params: { sort: 'created_at_asc' },
          headers: dpop_headers_for(current_user))

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('public_api/v4/resource_access_tokens')
        expect(json_response[0]['id']).to eq(created_2_days_ago_token.id)
        expect(json_response[0]['resource_type']).to eq('project')
        expect(json_response[0]['resource_id']).to eq(project.id)
      end

      it 'avoids N+1 queries' do
        dpop_header_val = dpop_headers_for(current_user)

        get(api(path, personal_access_token: personal_access_token), headers: dpop_header_val)

        control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
          get(api(path, personal_access_token: personal_access_token), headers: dpop_header_val)
        end

        other_bot = create(:user, :project_bot, bot_namespace: group, developer_of: group)
        create(:personal_access_token, user: other_bot)

        expect do
          get(api(path, personal_access_token: personal_access_token), headers: dpop_header_val)
        end.not_to exceed_all_query_limit(control)
      end
    end
  end

  describe 'GET /groups/:id/manage/ssh_keys' do
    let_it_be(:path) { "/groups/#{group.id}/manage/ssh_keys" }

    it_behaves_like 'feature is not available to non saas versions', "get_request"

    context 'when saas', :saas do
      it 'throws not found error for a non existent group' do
        get(api("/groups/#{non_existing_record_id}/manage/ssh_keys"), headers: dpop_headers_for(current_user))

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it_behaves_like 'a manage groups GET endpoint'

      context 'when group has no enterprise user associated' do
        let_it_be(:user) { create(:user) }
        let_it_be(:ssh_key) { create(:personal_key, user: user) }

        it 'returns empty response for group which has no enterprise user associated' do
          group.add_developer(user)

          get(api(path, personal_access_token: personal_access_token), headers: dpop_headers_for(current_user))

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to eq([])
        end
      end

      context 'when group has enterprise_user associated' do
        let_it_be(:user) { create(:enterprise_user, enterprise_group: group) }

        it "returns the ssh_keys for the group" do
          ssh_key = create(:personal_key, user: user)

          get(api(path, personal_access_token: personal_access_token), headers: dpop_headers_for(current_user))

          expect(response).to have_gitlab_http_status(:ok)
          expect_paginated_array_response_contain_exactly(ssh_key.id)
          expect(json_response[0]['user_id']).to eq(user.id)
        end

        it 'avoids N+1 queries' do
          dpop_header_val = dpop_headers_for(current_user)
          control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
            get(api(path, personal_access_token: personal_access_token), headers: dpop_header_val)
          end

          user2 = create(:enterprise_user, enterprise_group: group)
          create(:personal_key, user: user2)

          expect do
            get(api(path, personal_access_token: personal_access_token), headers: dpop_header_val)
          end.not_to exceed_all_query_limit(control)
        end

        context 'with filter params', :freeze_time do
          subject(:get_request) do
            get api(path, personal_access_token: personal_access_token), params: params,
              headers: dpop_headers_for(current_user)
          end

          let(:params) { {} }

          context 'when created_at date filters' do
            let_it_be(:ssh_key_created_1_day_ago) { create(:personal_key, user: user, created_at: 1.day.ago.to_date) }
            let_it_be(:ssh_key_created_2_day_ago) { create(:personal_key, user: user, created_at: 2.days.ago.to_date) }
            let_it_be(:ssh_key_created_3_day_ago) { create(:personal_key, user: user, created_at: 3.days.ago.to_date) }

            it "returns keys filtered with created_before the params value" do
              params[:created_before] = 2.days.ago.to_date

              get_request

              expect(response).to have_gitlab_http_status(:ok)
              expect_paginated_array_response([ssh_key_created_2_day_ago.id, ssh_key_created_3_day_ago.id])
              expect(json_response.count).to eq(2)
            end

            it "returns keys filtered with created_after the params value" do
              params[:created_after] = 2.days.ago.to_date

              get_request

              expect(response).to have_gitlab_http_status(:ok)
              expect_paginated_array_response([ssh_key_created_1_day_ago.id, ssh_key_created_2_day_ago.id])
              expect(json_response.count).to eq(2)
            end
          end

          context 'when expires_at date filters' do
            let_it_be(:ssh_key_expiring_in_1_day) do
              create(:personal_key, user: user, expires_at: 1.day.from_now.to_date)
            end

            let_it_be(:ssh_key_expiring_in_2_day) do
              create(:personal_key, user: user, expires_at: 2.days.from_now.to_date)
            end

            let_it_be(:ssh_key_expiring_in_3_day) do
              create(:personal_key, user: user, expires_at: 3.days.from_now.to_date)
            end

            it "returns keys filtered with expires_before the params value" do
              params[:expires_before] = 2.days.from_now.to_date

              get_request

              expect(response).to have_gitlab_http_status(status)
              expect_paginated_array_response([ssh_key_expiring_in_1_day.id, ssh_key_expiring_in_2_day.id])
              expect(json_response.count).to eq(2)
            end

            it "returns keys filtered with expires_after the params value" do
              params[:expires_after] = 2.days.from_now.to_date

              get_request

              expect(response).to have_gitlab_http_status(status)
              expect_paginated_array_response([ssh_key_expiring_in_2_day.id, ssh_key_expiring_in_3_day.id])
              expect(json_response.count).to eq(2)
            end
          end
        end
      end
    end
  end
end
