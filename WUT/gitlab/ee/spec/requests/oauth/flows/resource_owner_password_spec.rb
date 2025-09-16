# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'GitLab OAuth2 Resource Owner Password Credentials Flow', feature_category: :system_access do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:application) { create(:oauth_application, redirect_uri: 'urn:ietf:wg:oauth:2.0:oob') }
  let_it_be(:user) { create(:user, :with_namespace, organizations: [organization], password: 'High5ive!') }
  let_it_be(:client_id) { application.uid }
  let_it_be(:client_secret) { application.secret }

  let(:token_params) do
    {
      client_id: client_id,
      client_secret: client_secret,
      grant_type: 'password',
      username: user.username,
      password: user.password,
      scope: 'api'
    }
  end

  let(:headers) do
    credentials = Base64.encode64("#{client_id}:#{client_secret}")
    { "HTTP_AUTHORIZATION" => "Basic #{credentials}" }
  end

  def fetch_access_token(params)
    post oauth_token_path, params: params
    json_response
  end

  describe 'Token Request with Resource Owner Password' do
    context 'when ROPC is disabled for an application' do
      before do
        stub_saas_features(disable_ropc_for_new_applications: true)
        application.update!(ropc_enabled: false)
      end

      it 'returns an error' do
        token_response = fetch_access_token(token_params)

        expect(response).to have_gitlab_http_status(:unauthorized)
        expect(token_response['error']).to eq('unauthorized_client')
      end

      context 'when the feature is disabled' do
        before do
          stub_feature_flags(disable_ropc_for_new_applications: false)
        end

        it 'returns an access token' do
          token_response = fetch_access_token(token_params)

          expect(response).to have_gitlab_http_status(:ok)
          expect(token_response).to include('access_token', 'token_type', 'expires_in', 'refresh_token')
        end
      end
    end
  end
end
