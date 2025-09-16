# frozen_string_literal: true

require 'spec_helper'

RSpec.describe OmniAuth::Strategies::GroupSaml, feature_category: :system_access, type: :strategy do
  include Gitlab::Routing

  let(:strategy) { [described_class, {}] }
  let!(:group) { create(:group, name: 'my-group') }
  let(:idp_sso_url) { 'https://saml.example.com/adfs/ls' }
  let(:fingerprint) { 'C1:59:74:2B:E8:0C:6C:A9:41:0F:6E:83:F6:D1:52:25:45:58:89:FB' }
  let!(:saml_provider) { create(:saml_provider, group: group, sso_url: idp_sso_url, certificate_fingerprint: fingerprint) }
  let!(:unconfigured_group) { create(:group, name: 'unconfigured-group') }
  let(:saml_response) do
    fixture = File.read('ee/spec/fixtures/saml/response.xml')
    Base64.encode64(fixture)
  end

  before do
    stub_licensed_features(group_saml: true)
  end

  describe 'callback_path option' do
    let(:callback_path) { described_class.default_options[:callback_path] }

    def check(path)
      callback_path.call("PATH_INFO" => path)
    end

    it 'dynamically detects /groups/:group_path/-/saml/callback' do
      expect(check("/groups/some-group/-/saml/callback")).to be_truthy
    end

    it 'rejects default callback paths' do
      expect(check('/saml/callback')).to be_falsey
      expect(check('/auth/saml/callback')).to be_falsey
      expect(check('/auth/group_saml/callback')).to be_falsey
      expect(check('/users/auth/saml/callback')).to be_falsey
      expect(check('/users/auth/group_saml/callback')).to be_falsey
    end
  end

  describe 'callback_url option' do
    let(:base_url) { 'https://example.com' }

    it 'calls callback_url in the original strategy' do
      strategy = described_class.new({})

      allow(strategy).to receive(:full_host) { base_url }
      allow(strategy).to receive(:callback_path).and_return('/v1/users/auth/group_saml/callback')
      allow(strategy).to receive(:query_string).and_return("?group_path=#{group.name}")

      expect(strategy.callback_url).to eq("#{base_url}/v1/users/auth/group_saml/callback?group_path=#{group.name}")
    end
  end

  describe 'POST /groups/:group_path/-/saml/callback' do
    context 'with valid SAMLResponse' do
      before do
        allow_next_instance_of(OneLogin::RubySaml::Response) do |instance|
          allow(instance).to receive(:validate_signature) { true }
          allow(instance).to receive(:validate_session_expiration) { true }
          allow(instance).to receive(:validate_subject_confirmation) { true }
          allow(instance).to receive(:validate_conditions) { true }
        end
      end

      it 'sets the auth hash based on the response' do
        post "/groups/my-group/-/saml/callback", SAMLResponse: saml_response

        expect(auth_hash[:info]['email']).to eq("user@example.com")
      end

      it 'sets omniauth setings from configured settings' do
        post "/groups/my-group/-/saml/callback", SAMLResponse: saml_response

        options = last_request.env['omniauth.strategy'].options
        expect(options['idp_cert_fingerprint']).to eq fingerprint
      end

      it 'redirects to failure endpoint when SAML is disabled for the group' do
        saml_provider.update!(enabled: false)
        post "/groups/my-group/-/saml/callback", SAMLResponse: saml_response
        expect(last_response.status).to eq(302)
        expect(last_response.location).to eq("/users/auth/failure?message=my-group&strategy=group_saml")
      end

      context 'user is testing SAML response' do
        let(:relay_state) { ::OmniAuth::Strategies::GroupSaml::VERIFY_SAML_RESPONSE }
        let(:mock_session) do
          rack_session = Rack::Session::SessionId.new('6919a6f1bb119dd7396fadc38fd18d0d')
          instance_spy(ActionDispatch::Request::Session, id: rack_session, '[]': {})
        end

        it 'stores the saml response for retrieval after redirect' do
          expect_next_instance_of(::Gitlab::Auth::GroupSaml::ResponseStore) do |instance|
            allow(instance).to receive(:set_raw).with(saml_response)
          end

          post "/groups/my-group/-/saml/callback",
            { SAMLResponse: saml_response, RelayState: relay_state },
            'rack.session' => mock_session
        end

        it 'redirects back to the settings page' do
          post "/groups/my-group/-/saml/callback",
            { SAMLResponse: saml_response, RelayState: relay_state },
            'rack.session' => mock_session

          expect(last_response.location).to eq(group_saml_providers_path(group, anchor: 'response'))
        end
      end
    end

    context 'with invalid SAMLResponse' do
      it 'redirects somewhere so failure messages can be displayed' do
        post "/groups/my-group/-/saml/callback", SAMLResponse: saml_response

        expect(last_response.location).to include('failure')
      end
    end

    it 'redirects to failure endpoint when the group is not found' do
      post "/groups/not-a-group/-/saml/callback", SAMLResponse: saml_response
      expect(last_response.status).to eq(302)
      expect(last_response.location).to eq("/users/auth/failure?message=not-a-group&strategy=group_saml")
    end

    context 'Group SAML not licensed for group' do
      before do
        stub_licensed_features(group_saml: false)
      end

      it 'redirects to failure endpoint' do
        post "/groups/my-group/-/saml/callback", SAMLResponse: saml_response
        expect(last_response.status).to eq(302)
        expect(last_response.location).to eq("/users/auth/failure?message=my-group&strategy=group_saml")
      end
    end
  end

  describe 'POST /users/auth/group_saml' do
    before do
      mock_session = {}

      allow(mock_session).to receive(:enabled?).and_return(true)
      allow(mock_session).to receive(:loaded?).and_return(true)

      env('rack.session', mock_session)
    end

    it 'redirects to the provider login page', :aggregate_failures do
      post '/users/auth/group_saml', group_path: 'my-group'

      expect(last_response.status).to eq(302)
      expect(last_response.location).to match(/\A#{Regexp.quote(idp_sso_url)}/)
    end

    it 'redirects to failure endpoint for groups without SAML configured' do
      post '/users/auth/group_saml', group_path: 'unconfigured-group'
      expect(last_response.status).to eq(302)
      expect(last_response.location).to eq("/users/auth/failure?message=unconfigured-group&strategy=group_saml")
    end

    it 'redirects to the failure endpoint when the group is not found' do
      post '/users/auth/group_saml', group_path: 'not-a-group'
      expect(last_response.status).to eq(302)
      expect(last_response.location).to eq("/users/auth/failure?message=not-a-group&strategy=group_saml")
    end

    it 'redirects to failure endpoint when missing group_path param' do
      post '/users/auth/group_saml'
      expect(last_response.status).to eq(302)
      expect(last_response.location).to eq("/users/auth/failure?message=ActionController%3A%3ARoutingError&strategy=group_saml")
    end

    it "stores request ID during request phase" do
      request_id = double
      allow_next_instance_of(OneLogin::RubySaml::Authrequest) do |instance|
        allow(instance).to receive(:uuid).and_return(request_id)
      end

      post '/users/auth/group_saml', group_path: 'my-group'

      expect(session['last_authn_request_id']).to eq(request_id)
    end
  end

  describe 'POST /users/auth/group_saml/metadata' do
    it 'redirects to the failure endpoint when the group is not found' do
      post '/users/auth/group_saml/metadata', group_path: 'not-a-group'
      expect(last_response.status).to eq(302)
      expect(last_response.location).to eq("/users/auth/failure?message=not-a-group&strategy=group_saml")
    end

    it 'redirects to the failure endpoint with generic error to avoid disclosing group existence' do
      post '/users/auth/group_saml/metadata', group_path: 'my-group'
      expect(last_response.status).to eq(302)
      expect(last_response.location).to eq("/users/auth/failure?message=my-group&strategy=group_saml")
    end

    it 'returns metadata when a valid token is provided' do
      post '/users/auth/group_saml/metadata', group_path: 'my-group', token: group.saml_discovery_token

      expect(last_response.status).to eq 200
      expect(last_response.body).to start_with('<?xml')
      expect(last_response.header["Content-Type"]).to eq "application/xml"
    end

    it 'redirects to failure endpoint when an invalid token is provided' do
      post '/users/auth/group_saml/metadata', group_path: 'my-group', token: 'invalidtoken'
      expect(last_response.status).to eq(302)
      expect(last_response.location).to eq("/users/auth/failure?message=my-group&strategy=group_saml")
    end

    it 'redirects to failure endpoint when group is not found but a token is provided' do
      post '/users/auth/group_saml/metadata', group_path: 'not-a-group', token: 'dummytoken'
      expect(last_response.status).to eq(302)
      expect(last_response.location).to eq("/users/auth/failure?message=not-a-group&strategy=group_saml")
    end

    it 'sets omniauth setings from default settings' do
      post '/users/auth/group_saml/metadata', group_path: 'my-group', token: group.saml_discovery_token

      options = last_request.env['omniauth.strategy'].options
      expect(options['assertion_consumer_service_url']).to end_with "/groups/my-group/-/saml/callback"
    end
  end

  describe 'POST /users/auth/group_saml/slo' do
    it 'returns 404 to avoid disclosing group existence' do
      post '/users/auth/group_saml/slo', group_path: 'my-group'

      expect(last_response).to be_not_found
    end
  end

  describe 'POST /users/auth/group_saml/spslo' do
    it 'returns 404 to avoid disclosing group existence' do
      post '/users/auth/group_saml/spslo', group_path: 'my-group'

      expect(last_response).to be_not_found
    end
  end
end
