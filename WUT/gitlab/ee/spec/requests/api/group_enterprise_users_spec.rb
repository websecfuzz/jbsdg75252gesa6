# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::GroupEnterpriseUsers, :aggregate_failures, feature_category: :user_management do
  let_it_be(:enterprise_group) { create(:group) }
  let_it_be(:saml_provider) { create(:saml_provider, group: enterprise_group) }

  let_it_be(:subgroup) { create(:group, parent: enterprise_group) }

  let_it_be(:developer_of_enterprise_group) { create(:user, developer_of: enterprise_group) }
  let_it_be(:maintainer_of_enterprise_group) { create(:user, maintainer_of: enterprise_group) }
  let_it_be(:owner_of_enterprise_group) { create(:user, owner_of: enterprise_group) }

  let_it_be(:non_enterprise_user) { create(:user) }
  let_it_be(:enterprise_user_of_another_group) { create(:enterprise_user) }

  let_it_be(:enterprise_user_of_the_group) do
    create(:enterprise_user, :with_namespace, enterprise_group: enterprise_group).tap do |user|
      create(:group_saml_identity, user: user, saml_provider: saml_provider)
      create(:scim_identity, user: user, group: enterprise_group)
    end
  end

  let_it_be(:blocked_enterprise_user_of_the_group) do
    create(:enterprise_user, :blocked, :with_namespace, enterprise_group: enterprise_group)
  end

  let_it_be(:enterprise_user_and_member_of_the_group) do
    create(:enterprise_user, :with_namespace, enterprise_group: enterprise_group, developer_of: enterprise_group)
  end

  let(:current_user) { owner_of_enterprise_group }
  let(:group_id) { enterprise_group.id }
  let(:user_id) { enterprise_user_of_the_group.id }
  let(:params) { {} }

  shared_examples 'authentication and authorization requirements' do
    context 'when current_user is nil' do
      let(:current_user) { nil }

      it 'returns 401 Unauthorized' do
        subject

        expect(response).to have_gitlab_http_status(:unauthorized)
        expect(json_response['message']).to eq('401 Unauthorized')
      end
    end

    context 'when group is not found' do
      let(:group_id) { -42 }

      it 'returns 404 Group Not Found' do
        subject

        expect(response).to have_gitlab_http_status(:not_found)
        expect(json_response['message']).to eq('404 Group Not Found')
      end
    end

    context 'when group is not top-level group' do
      let(:group_id) { subgroup.id }

      it 'returns 400 Bad Request with message' do
        subject

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['message']).to eq('400 Bad request - Must be a top-level group')
      end
    end

    context 'when current_user is not owner of the group' do
      let(:current_user) { maintainer_of_enterprise_group }

      it 'returns 403 Forbidden' do
        subject

        expect(response).to have_gitlab_http_status(:forbidden)
        expect(json_response['message']).to eq('403 Forbidden')
      end
    end
  end

  describe 'GET /groups/:id/enterprise_users' do
    subject(:get_group_enterprise_users) do
      get api("/groups/#{group_id}/enterprise_users", current_user), params: params
    end

    include_examples 'authentication and authorization requirements'

    it_behaves_like 'internal event tracking' do
      let(:event) { 'use_get_group_enterprise_users_api' }
      let(:user) { current_user }
      let(:namespace) { enterprise_group }

      subject(:track_event) { get_group_enterprise_users }
    end

    it 'returns enterprise users of the group in descending order by id' do
      get_group_enterprise_users

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response.pluck('id')).to eq(
        [
          enterprise_user_of_the_group,
          blocked_enterprise_user_of_the_group,
          enterprise_user_and_member_of_the_group
        ].sort_by(&:id).reverse.pluck(:id)
      )
    end

    context 'for pagination parameters' do
      let(:params) { { page: 1, per_page: 2 } }

      it 'returns enterprise users according to page and per_page parameters' do
        get_group_enterprise_users

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.pluck('id')).to eq(
          [
            enterprise_user_of_the_group,
            blocked_enterprise_user_of_the_group,
            enterprise_user_and_member_of_the_group
          ].sort_by(&:id).reverse.slice(0, 2).pluck(:id)
        )
      end
    end

    context 'for username parameter' do
      let(:params) { { username: enterprise_user_of_the_group.username } }

      it 'returns single enterprise user with a specific username' do
        get_group_enterprise_users

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.count).to eq(1)
        expect(json_response.first['id']).to eq(enterprise_user_of_the_group.id)
      end
    end

    context 'for search parameter' do
      context 'for search by name' do
        let(:params) { { search: enterprise_user_of_the_group.name } }

        it 'returns enterprise users of the group according to the search parameter' do
          get_group_enterprise_users

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.count).to eq(1)
          expect(json_response.first['id']).to eq(enterprise_user_of_the_group.id)
        end
      end

      context 'for search by username' do
        let(:params) { { search: blocked_enterprise_user_of_the_group.username } }

        it 'returns enterprise users of the group according to the search parameter' do
          get_group_enterprise_users

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.count).to eq(1)
          expect(json_response.first['id']).to eq(blocked_enterprise_user_of_the_group.id)
        end
      end

      context 'for search by public email' do
        let_it_be(:enterprise_user_of_the_group_with_public_email) do
          create(:enterprise_user, :public_email, :with_namespace, enterprise_group: enterprise_group)
        end

        let(:params) do
          { search: enterprise_user_of_the_group_with_public_email.public_email }
        end

        it 'returns enterprise users of the group according to the search parameter' do
          expect(enterprise_user_of_the_group_with_public_email.public_email).to be_present

          get_group_enterprise_users

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.count).to eq(1)
          expect(json_response.first['id']).to eq(enterprise_user_of_the_group_with_public_email.id)
        end
      end

      context 'for search by private email' do
        let_it_be(:enterprise_user_of_the_group_without_public_email) do
          create(:enterprise_user, :with_namespace, enterprise_group: enterprise_group)
        end

        let(:params) do
          { search: enterprise_user_of_the_group_without_public_email.email }
        end

        it 'returns enterprise users of the group according to the search parameter' do
          expect(enterprise_user_of_the_group_without_public_email.public_email).not_to be_present

          get_group_enterprise_users

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.count).to eq(1)
          expect(json_response.first['id']).to eq(enterprise_user_of_the_group_without_public_email.id)
        end
      end
    end

    context 'for active parameter' do
      let(:params) { { active: true } }

      it 'returns only active enterprise users' do
        get_group_enterprise_users

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.pluck('id')).to eq(
          [
            enterprise_user_of_the_group,
            enterprise_user_and_member_of_the_group
          ].sort_by(&:id).reverse.pluck(:id)
        )
      end
    end

    context 'for blocked parameter' do
      let(:params) { { blocked: true } }

      it 'returns only blocked enterprise users' do
        get_group_enterprise_users

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.pluck('id')).to eq(
          [
            blocked_enterprise_user_of_the_group
          ].sort_by(&:id).reverse.pluck(:id)
        )
      end
    end

    context 'for created_after parameter' do
      let(:params) { { created_after: 10.days.ago } }

      let_it_be(:enterprise_user_of_the_group_created_12_days_ago) do
        create(:enterprise_user, :with_namespace, enterprise_group: enterprise_group).tap do |user|
          user.update_column(:created_at, 12.days.ago)
        end
      end

      let_it_be(:enterprise_user_of_the_group_created_8_days_ago) do
        create(:enterprise_user, :with_namespace, enterprise_group: enterprise_group).tap do |user|
          user.update_column(:created_at, 8.days.ago)
        end
      end

      it 'returns only enterprise users created after the specified time', :freeze_time do
        get_group_enterprise_users

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.pluck('id')).to eq(
          [
            enterprise_user_of_the_group,
            blocked_enterprise_user_of_the_group,
            enterprise_user_and_member_of_the_group,
            enterprise_user_of_the_group_created_8_days_ago
          ].sort_by(&:id).reverse.pluck(:id)
        )
      end
    end

    context 'for created_before parameter' do
      let(:params) { { created_before: 10.days.ago } }

      let_it_be(:enterprise_user_of_the_group_created_12_days_ago) do
        create(:enterprise_user, :with_namespace, enterprise_group: enterprise_group).tap do |user|
          user.update_column(:created_at, 12.days.ago)
        end
      end

      let_it_be(:enterprise_user_of_the_group_created_8_days_ago) do
        create(:enterprise_user, :with_namespace, enterprise_group: enterprise_group).tap do |user|
          user.update_column(:created_at, 8.days.ago)
        end
      end

      it 'returns only enterprise users created before the specified time', :freeze_time do
        get_group_enterprise_users

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.pluck('id')).to eq(
          [
            enterprise_user_of_the_group_created_12_days_ago
          ].sort_by(&:id).reverse.pluck(:id)
        )
      end
    end

    context 'for two_factor parameter' do
      let_it_be(:enterprise_user_of_the_group_with_two_factor_enabled) do
        create(:enterprise_user, :two_factor, :with_namespace, enterprise_group: enterprise_group)
      end

      context 'when enabled value' do
        let(:params) { { two_factor: 'enabled' } }

        it 'returns only enterprise users with two-factor enabled' do
          get_group_enterprise_users

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.pluck('id')).to eq(
            [
              enterprise_user_of_the_group_with_two_factor_enabled
            ].sort_by(&:id).reverse.pluck(:id)
          )
        end
      end

      context 'when disabled value' do
        let(:params) { { two_factor: 'disabled' } }

        it 'returns only enterprise users with two-factor disabled' do
          get_group_enterprise_users

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.pluck('id')).to eq(
            [
              enterprise_user_of_the_group,
              blocked_enterprise_user_of_the_group,
              enterprise_user_and_member_of_the_group
            ].sort_by(&:id).reverse.pluck(:id)
          )
        end
      end
    end
  end

  describe 'GET /groups/:id/enterprise_users/:user_id' do
    subject(:get_group_enterprise_user) do
      get api("/groups/#{group_id}/enterprise_users/#{user_id}", current_user)
    end

    include_examples 'authentication and authorization requirements'

    it 'returns the enterprise user of the group' do
      get_group_enterprise_user

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['id']).to eq(enterprise_user_of_the_group.id)
    end

    context 'when user_id does not refer to an enterprise user of the group' do
      let(:user_id) { enterprise_user_of_another_group.id }

      it 'returns 404 Not found' do
        get_group_enterprise_user

        expect(response).to have_gitlab_http_status(:not_found)
        expect(json_response['message']).to eq('404 Not found')
      end
    end
  end

  describe 'PATCH /groups/:id/enterprise_users/:user_id/disable_two_factor', :saas do
    before do
      stub_licensed_features(domain_verification: true)
    end

    let_it_be(:enterprise_user_of_the_group_with_two_factor_enabled) do
      create(:enterprise_user, :two_factor, :with_namespace, enterprise_group: enterprise_group)
    end

    subject(:disable_enterprise_user_two_factor) do
      patch api("/groups/#{group_id}/enterprise_users/#{user_id}/disable_two_factor", current_user)
    end

    include_examples 'authentication and authorization requirements'

    context 'when the enterprise user has two-factor authentication enabled' do
      let(:user_id) { enterprise_user_of_the_group_with_two_factor_enabled.id }

      it 'disables 2FA for the user' do
        expect { disable_enterprise_user_two_factor }.to change {
          enterprise_user_of_the_group_with_two_factor_enabled.reload.two_factor_enabled?
        }.from(true).to(false)
        expect(response).to have_gitlab_http_status(:no_content)
      end
    end

    context 'when the enterprise user does not have two-factor authentication enabled' do
      it 'returns 400 Bad request' do
        disable_enterprise_user_two_factor

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['message']).to eq(
          '400 Bad request - Two-factor authentication is not enabled for this user')
      end
    end

    context 'when user_id does not refer to an enterprise user of the group' do
      let(:user_id) { enterprise_user_of_another_group.id }

      it 'returns 404 Not found' do
        disable_enterprise_user_two_factor

        expect(response).to have_gitlab_http_status(:not_found)
        expect(json_response['message']).to eq('404 Not found')
      end
    end
  end
end
