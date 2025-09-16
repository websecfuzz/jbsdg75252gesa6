# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::GroupServiceAccounts, :aggregate_failures, feature_category: :user_management do
  include Auth::DpopTokenHelper

  let_it_be(:organization) { create(:organization) }
  let_it_be(:user) { create(:user) }
  let_it_be(:personal_access_token) { create(:personal_access_token, user: user) }
  let(:current_user) { create(:user) }
  let(:group) { create(:group, organization: organization) }
  let(:subgroup) { create(:group, :private, parent: group) }

  let_it_be(:service_account_user) { create(:user, :service_account) }

  before do
    stub_application_setting_enum('email_confirmation_setting', 'hard')

    service_account_user.provisioned_by_group_id = group.id
    service_account_user.save!
  end

  RSpec.shared_examples "service account user deletion" do
    it "marks user for deletion", :sidekiq_inline do
      perform_enqueued_jobs { delete api(path, admin, admin_mode: true) }

      expect(response).to have_gitlab_http_status(:no_content)
      expect(Users::GhostUserMigration.where(user: service_account_user, initiator_user: admin)).to exist
    end

    context "when sole owner of a group" do
      let!(:new_group) { create(:group, owners: service_account_user) }

      context "when hard delete disabled" do
        it "does not mark  user for deletion" do
          perform_enqueued_jobs { delete api(path, admin, admin_mode: true) }
          expect(service_account_user.blocked?).to eq(false)
          expect(Users::GhostUserMigration.where(user: service_account_user, initiator_user: admin,
            hard_delete: false)).not_to exist
          expect(response).to have_gitlab_http_status(:conflict)
        end
      end

      context "when hard delete enabled" do
        let!(:another_group) { create(:group, owners: service_account_user) }

        it "marks user for deletion and group is deleted", :sidekiq_inline do
          perform_enqueued_jobs do
            delete api("/groups/#{group_id}/service_accounts/#{service_account_user.id}?hard_delete=true", admin,
              admin_mode: true)
          end
          expect(response).to have_gitlab_http_status(:no_content)
          expect(Users::GhostUserMigration.where(user: service_account_user, initiator_user: admin,
            hard_delete: true)).to exist
          expect(service_account_user.reload.blocked?).to eq(true)
          expect(Group.exists?(another_group.id)).to eq(false)
        end

        context "when there is a subgroup" do
          let(:parent_group) { create(:group) }
          let(:subgroup) { create(:group, parent: parent_group) }

          before do
            parent_group.add_owner(create(:user))
            subgroup.add_owner(user)
          end

          it "marks only user for deletion and group is not deleted", :sidekiq_inline do
            perform_enqueued_jobs do
              delete api("/groups/#{group_id}/service_accounts/#{service_account_user.id}?hard_delete=true", admin,
                admin_mode: true)
            end
            expect(response).to have_gitlab_http_status(:no_content)
            expect(Group.exists?(subgroup.id)).to eq(true)
            expect(Users::GhostUserMigration.where(user: service_account_user, initiator_user: admin,
              hard_delete: true)).to exist
            expect(service_account_user.reload.blocked?).to eq(true)
          end
        end
      end
    end

    it "fails for unauthenticated user" do
      perform_enqueued_jobs { delete api(path) }
      expect(service_account_user.reload.blocked?).to eq(false)
      expect(response).to have_gitlab_http_status(:unauthorized)
    end

    it "returns 404 for non-existing user" do
      perform_enqueued_jobs do
        delete api("/groups/#{group_id}/service_accounts/#{non_existing_record_id}", admin, admin_mode: true)
      end

      expect(response).to have_gitlab_http_status(:not_found)
      expect(json_response['message']).to eq('404 User Not Found')
    end

    it "returns a 400 for invalid ID" do
      perform_enqueued_jobs { delete api("/groups/#{group_id}/service_accounts/ASDF", admin, admin_mode: true) }

      expect(response).to have_gitlab_http_status(:bad_request)
    end

    context "when hard delete disabled" do
      it "moves contributions to the ghost user", :sidekiq_might_not_need_inline do
        perform_enqueued_jobs { delete api(path, admin, admin_mode: true) }

        expect(response).to have_gitlab_http_status(:no_content)
        expect(issue.reload).to be_persisted
        expect(Users::GhostUserMigration.where(user: service_account_user, initiator_user: admin,
          hard_delete: false)).to exist
        expect(service_account_user.reload.blocked?).to eq(true)
      end
    end

    context "when hard delete enabled" do
      it "removes contributions", :sidekiq_might_not_need_inline do
        perform_enqueued_jobs do
          delete api("/groups/#{group_id}/service_accounts/#{service_account_user.id}?hard_delete=true", admin,
            admin_mode: true)
        end

        expect(response).to have_gitlab_http_status(:no_content)
        expect(Users::GhostUserMigration.where(user: service_account_user, initiator_user: admin,
          hard_delete: true)).to exist
      end
    end
  end

  RSpec.shared_examples "service account user creation" do
    context 'when the group exists' do
      let(:group_id) { group.id }

      it "creates user and responds with the default values" do
        perform_request

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['username']).to start_with("service_account_group_#{group_id}")
        expect(json_response['name']).to eq('Service account user')
        expect(json_response['email']).to start_with("service_account_group_#{group_id}")
        expect(json_response.keys).to match_array(%w[id name username email public_email])
      end

      it 'creates the user with the correct attributes' do
        perform_request

        user = User.find(json_response['id'])

        expect(user.namespace.organization).to eq(organization)
        expect(user.user_type).to eq('service_account')
        expect(user).to be_confirmed
      end

      context 'when params are provided' do
        let_it_be(:params) do
          {
            name: 'John Doe',
            username: 'test',
            email: 'test_service_account@example.com'
          }
        end

        it "creates user with provided details" do
          perform_request

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['username']).to eq(params[:username])
          expect(json_response['name']).to eq(params[:name])
          expect(json_response['email']).to eq(params[:email])
          expect(json_response.keys).to match_array(%w[id name username email public_email])
        end

        it 'creates the user with the correct attributes' do
          perform_request

          user = User.find(json_response['id'])

          expect(user.namespace.organization).to eq(organization)
          expect(user.user_type).to eq('service_account')
          expect(user).not_to be_confirmed
        end

        context 'when user with the username and email already exists' do
          before do
            post api("/groups/#{group_id}/service_accounts", user), params: params
          end

          it 'returns error' do
            perform_request

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['message']).to include('Username has already been taken')
            expect(json_response['message']).to include('Email has already been taken')
          end
        end

        context 'when the group does not exist' do
          let(:group_id) { non_existing_record_id }

          it "returns error" do
            perform_request

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end
      end

      it "returns bad request when service returns bad request" do
        allow_next_instance_of(::Namespaces::ServiceAccounts::CreateService) do |service|
          allow(service).to receive(:execute).and_return(
            ServiceResponse.error(message: message, reason: :bad_request)
          )
        end

        perform_request

        expect(response).to have_gitlab_http_status(:bad_request)
      end

      context 'for subgroup' do
        let(:group_id) { subgroup.id }

        it 'returns error' do
          perform_request

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['message']).to include(
            s_('ServiceAccount|User does not have permission to create a service account in this namespace.')
          )
        end
      end
    end

    context 'when the group does not exist' do
      let(:group_id) { non_existing_record_id }

      it "returns error" do
        perform_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  RSpec.shared_examples "service account user update" do
    context 'when the group exists' do
      let(:group_id) { group.id }

      it 'updates the service account user' do
        perform_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.keys).to match_array(%w[id name username email public_email])
        expect(json_response['name']).to eq(params[:name])
        expect(json_response['username']).to eq(params[:username])
      end

      context 'when email is provided' do
        let(:params) { { email: 'test@test.com' } }

        it 'only updates the unconfirmed email' do
          perform_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.keys).to match_array(%w[id name username email public_email unconfirmed_email])
          expect(json_response['unconfirmed_email']).to eq('test@test.com')
          expect(json_response['email']).not_to eq('test@test.com')
        end
      end

      context 'when user with the username already exists' do
        let(:existing_user) { create(:user, username: 'existing_user') }
        let(:params) { { username: existing_user.username } }

        it 'returns error' do
          perform_request

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['message']).to include('Username has already been taken')
        end
      end

      it "returns 404 for non-existing user" do
        patch api("/groups/#{group_id}/service_accounts/#{non_existing_record_id}", user), params: params

        expect(response).to have_gitlab_http_status(:not_found)
        expect(json_response['message']).to eq('404 User Not Found')
      end

      it "returns a 400 for invalid user ID" do
        patch api("/groups/#{group_id}/service_accounts/ASDF", user), params: params

        expect(response).to have_gitlab_http_status(:bad_request)
      end

      context 'when target user is not a service account' do
        let(:regular_user) { create(:user, provisioned_by_group: group) }

        it 'returns bad request error' do
          patch api("/groups/#{group_id}/service_accounts/#{regular_user.id}", user), params: params

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['message']).to include('User is not of type Service Account')
        end
      end
    end

    context 'when the group does not exist' do
      let(:group_id) { non_existing_record_id }

      it "returns error" do
        perform_request

        expect(response).to have_gitlab_http_status(:not_found)
        expect(json_response['message']).to include('404 Group Not Found')
      end
    end
  end

  describe "POST /groups/:id/service_accounts" do
    subject(:perform_request) { post api("/groups/#{group_id}/service_accounts", user), params: params }

    let_it_be(:params) { {} }

    before do
      stub_licensed_features(service_accounts: true)
      allow(License).to receive(:current).and_return(license)
    end

    context 'when the feature is licensed' do
      let(:license) { create(:license, plan: License::ULTIMATE_PLAN) }

      context 'when current user is an admin', :enable_admin_mode do
        let_it_be(:user) { create(:admin) }

        it_behaves_like "service account user creation"
      end

      context 'when current user is a group owner' do
        let_it_be(:user) { create(:user) }

        before do
          group.add_owner(user)
        end

        context 'when allow top level setting is activated' do
          before do
            stub_ee_application_setting(allow_top_level_group_owners_to_create_service_accounts: true)
          end

          it_behaves_like "service account user creation"

          context 'when in GitLab.com', :saas do
            let(:hosted_plan) { create(:ultimate_plan) }

            before do
              create(:gitlab_subscription, namespace: group, hosted_plan: hosted_plan)
              stub_application_setting(check_namespace_plan: true)
            end

            it_behaves_like "service account user creation"

            context 'when group has a verified domain' do
              let(:group_id) { group.id }
              let_it_be(:params) do
                {
                  name: 'John Doe',
                  username: 'test',
                  email: 'test_service_account@example.com'
                }
              end

              before do
                stub_licensed_features(domain_verification: true)
                project = create(:project, group: group)
                create(:pages_domain, project: project, domain: 'example.com')
              end

              it 'creates a confirmed user' do
                perform_request

                user = User.find(json_response['id'])

                expect(user.namespace.organization).to eq(organization)
                expect(user.user_type).to eq('service_account')
                expect(user.email).to eq('test_service_account@example.com')
                expect(user).to be_confirmed
              end
            end
          end
        end

        context 'when allow top level setting is deactivated' do
          let(:group_id) { group.id }

          before do
            stub_ee_application_setting(allow_top_level_group_owners_to_create_service_accounts: false)
          end

          it 'returns error' do
            perform_request

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['message']).to include(
              s_('ServiceAccount|User does not have permission to create a service account in this namespace.')
            )
          end
        end
      end
    end

    context 'when the feature is not licensed' do
      let(:license) { nil }
      let(:group_id) { group.id }

      before do
        stub_licensed_features(service_accounts: false)
        group.add_owner(user)
      end

      it "returns error" do
        perform_request

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe "GET /groups/:id/service_accounts" do
    let(:group_id) { group.id }
    let(:path) { "/groups/#{group_id}/service_accounts" }
    let(:params) { {} }

    subject(:perform_request) { get api(path, user), params: params }

    before do
      stub_licensed_features(service_accounts: true)
    end

    context 'when request is correct' do
      let(:service_account_user2) { create(:user, :service_account, provisioned_by_group: group) }
      let(:regular_user) { create(:user) }

      before do
        regular_user.provisioned_by_group_id = group.id

        regular_user.save!
        service_account_user2.save!

        group.add_owner(user)
      end

      it 'returns 200 status and service account users list' do
        perform_request

        expect(response).to have_gitlab_http_status(:ok)

        expect(response).to match_response_schema('public_api/v4/user/safes')
        expect(json_response.size).to eq(2)

        expect(json_response.pluck("id")).not_to include(regular_user.id)
      end

      context 'when order by is specified' do
        let(:params) { { order_by: "username" } }
        let(:username1) { "Auser" }
        let(:username2) { "Buser" }

        before do
          service_account_user.username = username1
          service_account_user2.username = username2
          service_account_user.save!
        end

        it "returns ordered list by username in desc order" do
          perform_request

          expect(response).to match_response_schema('public_api/v4/user/safes')
          expect(json_response.size).to eq(2)
          expect_paginated_array_response(service_account_user2.id, service_account_user.id)
        end

        context "when sort order_by is specified" do
          let(:params) { { order_by: "username", sort: "asc" } }

          it "follows sorting order" do
            perform_request

            expect(response).to match_response_schema('public_api/v4/user/safes')
            expect(json_response.size).to eq(2)
            expect_paginated_array_response(service_account_user.id, service_account_user2.id)
          end

          it 'does not order by any other column than username and id' do
            get api(path, user), params: { order_by: "name" }

            expect(response).to have_gitlab_http_status(:bad_request)
          end
        end
      end

      it_behaves_like 'an endpoint with keyset pagination', invalid_order: nil do
        let(:first_record) { service_account_user2 }
        let(:second_record) { service_account_user }
        let(:api_call) { api(path, user) }
      end
    end

    context 'when group does not exist' do
      let(:group_id) { non_existing_record_id }

      it "returns error" do
        perform_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user is not group owner' do
      before do
        group.add_maintainer(user)
      end

      it "throws forbidden error" do
        perform_request

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when feature is not licensed' do
      before do
        stub_licensed_features(service_accounts: false)
        group.add_owner(user)
      end

      it 'returns error' do
        perform_request

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe "PATCH /groups/:id/service_accounts/:user_id" do
    let(:group_id) { group.id }
    let(:params) { { name: 'Updated Name', username: 'updated_username' } }

    subject(:perform_request) do
      patch api("/groups/#{group_id}/service_accounts/#{service_account_user.id}", user), params: params
    end

    context 'when feature is licensed' do
      before do
        stub_licensed_features(service_accounts: true)
      end

      context 'when current user is an admin' do
        let(:user) { create(:admin) }

        context 'when admin mode is not enabled' do
          it "returns forbidden error" do
            perform_request

            expect(response).to have_gitlab_http_status(:forbidden)
          end
        end

        context 'when admin mode is enabled', :enable_admin_mode do
          it_behaves_like "service account user update"
        end
      end

      context 'when current user is a group owner' do
        before do
          group.add_owner(user)
        end

        it_behaves_like "service account user update"

        context 'when saas', :saas do
          it_behaves_like "service account user update"

          context 'when group has a verified domain' do
            before do
              stub_licensed_features(service_accounts: true, domain_verification: true)
              project = create(:project, group: group)
              create(:pages_domain, project: project, domain: 'test.com')
            end

            let(:params) { super().merge(email: 'test@test.com') }

            it 'updates the email' do
              perform_request

              expect(response).to have_gitlab_http_status(:ok)
              expect(json_response['email']).to eq('test@test.com')
              expect(json_response.keys).to match_array(%w[id name username email public_email])
            end
          end
        end
      end

      context 'when current user is not a group owner' do
        before do
          group.add_maintainer(user)
        end

        it "returns forbidden error" do
          perform_request

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end

    context 'when feature is not licensed' do
      before do
        stub_licensed_features(service_accounts: false)
      end

      context 'when current user is an admin' do
        let(:current_user) { admin }

        context 'when admin mode is enabled', :enable_admin_mode do
          it "returns forbidden error" do
            perform_request

            expect(response).to have_gitlab_http_status(:forbidden)
          end
        end
      end
    end
  end

  describe "DELETE /groups/:id/service_accounts/:user_id" do
    let(:issue) { create(:issue, author: service_account_user) }
    let(:group_id) { group.id }
    let(:path) { "/groups/#{group_id}/service_accounts/#{service_account_user.id}" }
    let(:admin) { create(:admin) }

    before do
      stub_licensed_features(service_accounts: true)
    end

    it_behaves_like 'DELETE request permissions for admin mode'

    it_behaves_like "service account user deletion"

    it "is available for group owners when allow top level group owners application setting is enabled",
      :sidekiq_inline, :saas do
      group.add_owner(user)

      stub_ee_application_setting(allow_top_level_group_owners_to_create_service_accounts: true)
      perform_enqueued_jobs { delete api(path, user) }
      expect(response).to have_gitlab_http_status(:no_content)
      expect(Users::GhostUserMigration.where(user: service_account_user, initiator_user: user)).to exist
    end

    it "is not available to non group owners" do
      group.add_maintainer(user)
      stub_ee_application_setting(allow_top_level_group_owners_to_create_service_accounts: true)

      perform_enqueued_jobs { delete api(path, user) }
      expect(response).to have_gitlab_http_status(:forbidden)
    end

    context 'when feature is not licensed' do
      let(:group_id) { group.id }

      before do
        stub_licensed_features(service_accounts: false)
        group.add_owner(user)
      end

      it 'returns error' do
        perform_enqueued_jobs { delete api(path, service_account_user) }

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe "GET /groups/:id/service_accounts/:user_id/personal_access_tokens" do
    let(:group_id) { group.id }
    let(:target_user_id) { service_account_user.id }
    let(:path) { "/groups/#{group_id}/service_accounts/#{target_user_id}/personal_access_tokens" }
    let(:params) { nil }

    subject(:perform_request) { get(api(path, user), params: params) }

    context 'when the feature is licensed' do
      before do
        stub_licensed_features(service_accounts: true)
      end

      context 'when the user is a top-level-group owner' do
        before do
          group.add_owner(user)
        end

        context 'when the service_account is provisioned_by the group' do
          let_it_be(:current_user) { user }
          let_it_be(:active_token1) { create(:personal_access_token, user: service_account_user) }
          let_it_be(:active_token2) { create(:personal_access_token, user: service_account_user) }
          let_it_be(:expired_token1) do
            create(:personal_access_token, user: service_account_user, expires_at: 1.year.ago)
          end

          let_it_be(:expired_token2) do
            create(:personal_access_token, user: service_account_user, expires_at: 1.year.ago)
          end

          let_it_be(:revoked_token1) { create(:personal_access_token, user: service_account_user, revoked: true) }
          let_it_be(:revoked_token2) { create(:personal_access_token, user: service_account_user, revoked: true) }

          let_it_be(:created_2_days_ago_token) do
            create(:personal_access_token, user: service_account_user, created_at: 2.days.ago)
          end

          let_it_be(:named_token) { create(:personal_access_token, user: service_account_user, name: 'test_1') }
          let_it_be(:last_used_2_days_ago_token) do
            create(:personal_access_token, user: service_account_user, last_used_at: 2.days.ago)
          end

          let_it_be(:last_used_2_months_ago_token) do
            create(:personal_access_token, user: service_account_user, last_used_at: 2.months.ago)
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

          it_behaves_like 'an access token GET API with access token params'
        end

        context 'when the service_account is not provisioned_by the group' do
          before do
            service_account_user.provisioned_by_group_id = nil
            service_account_user.save!
          end

          it 'returns error' do
            perform_request

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end

        context 'when the target_user (service_account) is not a service account' do
          let(:regular_user) { create(:user) }

          before do
            regular_user.provisioned_by_group_id = group.id
            regular_user.save!
          end

          it 'returns bad request error' do
            get api(
              "/groups/#{group_id}/service_accounts/#{regular_user.id}/personal_access_tokens", user
            ), params: params

            expect(response).to have_gitlab_http_status(:bad_request)
          end
        end
      end

      context 'when group does not exist' do
        let(:group_id) { non_existing_record_id }

        it "returns error" do
          perform_request

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response['message']).to eq("404 Group Not Found")
        end
      end

      context 'when service account does not exist' do
        let(:service_account) { non_existing_record_id }

        it "returns error" do
          perform_request

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'when user is not a top-level-group owner' do
        before do
          group.add_maintainer(user)
        end

        it 'returns error' do
          perform_request

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'without authentication' do
        it 'returns error' do
          perform_request

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end

    context 'when feature is not licensed' do
      let(:group_id) { group.id }

      before do
        stub_licensed_features(service_accounts: false)
        group.add_owner(user)
      end

      it 'returns error' do
        perform_request

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe "POST /groups/:id/service_accounts/:user_id/personal_access_tokens" do
    let(:name) { 'new pat' }
    let(:description) { 'description' }
    let(:expires_at) { 3.days.from_now }
    let(:scopes) { %w[api read_user] }
    let(:params) { { name: name, description: description, expires_at: expires_at, scopes: scopes } }

    subject(:perform_request) do
      post(
        api("/groups/#{group_id}/service_accounts/#{service_account_user.id}/personal_access_tokens", user),
        params: params)
    end

    context 'when the feature is licensed' do
      let(:group_id) { group.id }
      let(:hosted_plan) { create(:ultimate_plan) }

      before do
        stub_licensed_features(service_accounts: true)
      end

      context 'when user is a group owner' do
        before do
          group.add_owner(user)
        end

        context 'when the group exists' do
          it 'creates personal access token for the user' do
            perform_request

            expect(response).to have_gitlab_http_status(:created)
            expect(json_response['name']).to eq(name)
            expect(json_response['description']).to eq(description)
            expect(json_response['scopes']).to eq(scopes)
            expect(json_response['expires_at']).to eq(expires_at.to_date.iso8601)
            expect(json_response['id']).to be_present
            expect(json_response['created_at']).to be_present
            expect(json_response['active']).to be_truthy
            expect(json_response['revoked']).to be_falsey
            expect(json_response['token']).to be_present
          end

          context 'when an error is thrown by the model' do
            let(:group_id) { group.id }
            let(:error_message) { 'error message' }
            let!(:admin_personal_access_token) { create(:personal_access_token, :admin_mode, user: create(:admin)) }

            before do
              allow_next_instance_of(::PersonalAccessTokens::CreateService) do |create_service|
                allow(create_service).to receive(:execute).and_return(
                  ServiceResponse.error(message: error_message)
                )
              end
            end

            it 'returns the error' do
              perform_request

              expect(response).to have_gitlab_http_status(:unprocessable_entity)
              expect(json_response['message']).to eq(error_message)
            end
          end

          context 'when service account does not belong to the group' do
            before do
              service_account_user.provisioned_by_group_id = nil
              service_account_user.save!
            end

            it 'returns error' do
              perform_request

              expect(response).to have_gitlab_http_status(:not_found)
            end
          end

          context 'when target user is not a service account' do
            let(:regular_user) { create(:user) }

            before do
              regular_user.provisioned_by_group_id = group.id
              regular_user.save!
            end

            it 'returns bad request error' do
              post api(
                "/groups/#{group_id}/service_accounts/#{regular_user.id}/personal_access_tokens", user
              ), params: params

              expect(response).to have_gitlab_http_status(:bad_request)
            end
          end
        end

        context 'when group does not exist' do
          let(:group_id) { non_existing_record_id }

          it "returns error" do
            perform_request

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end
      end

      context 'when user is not a group owner' do
        before do
          group.add_maintainer(user)
        end

        it 'returns error' do
          perform_request

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'without authentication' do
        it 'returns error' do
          perform_request

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end

    context 'when feature is not licensed' do
      let(:group_id) { group.id }

      before do
        stub_licensed_features(service_accounts: false)
        group.add_owner(user)
      end

      it 'returns error' do
        perform_request

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe 'DELETE /groups/:id/service_accounts/:user_id/personal_access_tokens/:token_id' do
    let(:group) { create(:group, organization: organization) }
    let(:service_account_user) { create(:user, :service_account, provisioned_by_group: group) }
    let(:admin) { create(:admin) }

    let(:token) { create(:personal_access_token, user: service_account_user) }
    let(:group_id) { group.id }
    let(:user_id) { service_account_user.id }
    let(:token_id) { token.id }
    let(:request_path) { "/groups/#{group_id}/service_accounts/#{user_id}/personal_access_tokens/#{token_id}" }

    subject(:revoke_token) { delete(api(request_path, current_user)) }

    shared_examples 'successful token revocation' do
      it 'revokes the token' do
        revoke_token

        expect(response).to have_gitlab_http_status(:no_content)
        expect(token.reload.revoked?).to be_truthy
      end
    end

    shared_examples 'token deletion unauthorized' do
      it 'returns a forbidden response' do
        revoke_token

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when the feature is licensed' do
      before do
        stub_licensed_features(service_accounts: true)
      end

      context 'when the requesting user is an admin' do
        let(:current_user) { admin }

        context 'when admin mode is enabled', :enable_admin_mode do
          it_behaves_like 'successful token revocation'
        end

        context 'when admin mode is not enabled' do
          it_behaves_like 'token deletion unauthorized'
        end
      end

      context 'when the requesting user is a group owner' do
        before do
          group.add_owner(current_user)
        end

        context 'when all parameters are valid' do
          it_behaves_like 'successful token revocation'
        end

        context 'when the revocation service fails' do
          let(:error_message) { 'error message' }

          before do
            allow_next_instance_of(::PersonalAccessTokens::RevokeService) do |service|
              allow(service).to receive(:execute).and_return(
                ServiceResponse.error(message: error_message)
              )
            end
          end

          it 'returns the error message' do
            revoke_token

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['message']).to eq('400 Bad request - error message')
          end
        end

        context 'when parameters are invalid' do
          context 'when the token does not exist' do
            let(:token_id) { non_existing_record_id }

            it 'returns not found' do
              revoke_token

              expect(response).to have_gitlab_http_status(:not_found)
            end
          end

          context 'when the token does not belong to the service account user' do
            let(:other_user) { create(:user) }
            let(:token) { create(:personal_access_token, user: other_user) }

            it 'returns not found' do
              revoke_token

              expect(response).to have_gitlab_http_status(:not_found)
              expect(json_response['message']).to eq("404 Personal Access Token Not Found")
            end
          end

          context 'when the service account does not belong to the group' do
            let(:other_group) { create(:group) }

            before do
              service_account_user.provisioned_by_group_id = other_group.id
              service_account_user.save!
            end

            it 'returns not found' do
              revoke_token

              expect(response).to have_gitlab_http_status(:not_found)
              expect(json_response['message']).to eq('404 User Not Found')
            end
          end

          context 'when the group does not exist' do
            let(:group_id) { non_existing_record_id }

            it 'returns not found' do
              revoke_token

              expect(response).to have_gitlab_http_status(:not_found)
            end
          end

          context 'when target user is not a service account' do
            let(:regular_user) { create(:user) }
            let(:user_id) { regular_user.id }
            let(:token) { create(:personal_access_token, user: regular_user) }

            before do
              regular_user.update!(provisioned_by_group_id: group.id)
            end

            it 'returns bad request error' do
              revoke_token

              expect(response).to have_gitlab_http_status(:bad_request)
            end
          end
        end
      end

      context 'when the requesting user does not have sufficient permissions' do
        context 'when user is not a group owner' do
          before do
            group.add_maintainer(current_user)
          end

          it_behaves_like 'token deletion unauthorized'
        end

        context 'without authentication' do
          let(:current_user) { nil }

          it 'returns unauthorized' do
            revoke_token

            expect(response).to have_gitlab_http_status(:unauthorized)
          end
        end
      end
    end

    context 'when the feature is not licensed' do
      before do
        stub_licensed_features(service_accounts: false)
        group.add_owner(current_user)
      end

      it 'returns forbidden' do
        revoke_token

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe 'POST /groups/:id/service_accounts/:user_id/personal_access_tokens/:token_id/rotate' do
    let(:group_id) { group.id }
    let(:user_id) { service_account_user.id }
    let(:token) { create(:personal_access_token, user: service_account_user) }
    let(:token_id) { token.id }
    let(:params) { nil }
    let(:path) do
      "/groups/#{group_id}/service_accounts/#{user_id}/personal_access_tokens/#{token_id}/rotate"
    end

    subject(:perform_request) do
      post(api(path, user), params: params)
    end

    context 'when the feature is licensed' do
      before do
        stub_licensed_features(service_accounts: true)
      end

      context 'when the user is an admin', :enable_admin_mode do
        let_it_be(:user) { create(:admin) }

        context 'when the group and token exist' do
          it 'revokes the token' do
            perform_request

            expect(response).to have_gitlab_http_status(:ok)
            expect(token.reload.revoked?).to be_truthy
            expect(json_response['token']).not_to eq(token.token)
            expect(json_response['expires_at']).to eq(1.week.from_now.to_date.iso8601)
          end
        end
      end

      context 'when user is a group owner' do
        before do
          group.add_owner(user)
        end

        context 'when the group exists' do
          it 'revokes the token' do
            perform_request

            expect(response).to have_gitlab_http_status(:ok)
            expect(token.reload.revoked?).to be_truthy
            expect(json_response['token']).not_to eq(token.token)
            expect(json_response['expires_at']).to eq(1.week.from_now.to_date.iso8601)
          end

          context 'when expiry is defined' do
            let(:expiry_date) { 1.month.from_now }
            let(:params) { { expires_at: expiry_date } }

            it "allows owner to rotate token", :freeze_time do
              perform_request

              expect(response).to have_gitlab_http_status(:ok)
              expect(token.reload.revoked?).to be_truthy
              expect(json_response['token']).not_to eq(token.token)
              expect(json_response['expires_at']).to eq(expiry_date.to_date.iso8601)
            end
          end

          context 'when service raises an error' do
            it 'returns error message' do
              token.revoke!
              perform_request

              expect(response).to have_gitlab_http_status(:bad_request)
              expect(json_response['message']).to eq("400 Bad request - Token already revoked")
            end
          end

          context 'when token does not exist' do
            let(:token_id) { non_existing_record_id }

            it 'returns not found' do
              perform_request

              expect(response).to have_gitlab_http_status(:not_found)
            end
          end

          context 'when token does not belong to service account user' do
            before do
              token.user = create(:user)
              token.save!
            end

            it 'returns bad request' do
              perform_request

              expect(response).to have_gitlab_http_status(:not_found)
            end
          end

          context 'when service account does not belong to the group' do
            before do
              service_account_user.provisioned_by_group_id = nil
              service_account_user.save!
            end

            it 'returns error' do
              perform_request

              expect(response).to have_gitlab_http_status(:not_found)
            end
          end

          context 'when target user is not a service account' do
            let(:regular_user) { create(:user) }
            let(:user_id) { regular_user.id }

            before do
              regular_user.provisioned_by_group_id = group.id
              regular_user.save!
              token.user = regular_user
              token.save!
            end

            it 'returns bad request error' do
              perform_request

              expect(response).to have_gitlab_http_status(:bad_request)
            end
          end
        end

        context 'when group does not exist' do
          let(:group_id) { non_existing_record_id }

          it 'returns error' do
            perform_request

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end
      end

      context 'when user is not a group owner' do
        it 'throws error' do
          perform_request

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end

    context 'when the feature is not licensed' do
      let(:group_id) { group.id }

      before do
        stub_licensed_features(service_accounts: false)
        group.add_owner(user)
      end

      it "returns error" do
        perform_request

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end
end
