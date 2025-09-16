# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'OAuth tokens', feature_category: :system_access do
  let_it_be(:organization) { create(:organization) }

  context 'for Resource Owner Password Credentials' do
    subject(:request_oauth_token) do
      post '/oauth/token', params: { username: user.username, password: user.password, grant_type: 'password' }
    end

    context 'for enterprise user' do
      let_it_be(:enterprise_group) { create(:group) }
      let_it_be(:user) { create(:enterprise_user, enterprise_group: enterprise_group, organizations: [organization]) }

      it 'creates an access token' do
        request_oauth_token

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['access_token']).to be_present
      end

      context 'when password authentication disabled by enterprise group' do
        let_it_be(:saml_provider) do
          create(
            :saml_provider,
            group: enterprise_group,
            enabled: true,
            disable_password_authentication_for_enterprise_users: true
          )
        end

        it 'does not create an access token' do
          request_oauth_token

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['error']).to eq('invalid_grant')
        end
      end
    end
  end
end
