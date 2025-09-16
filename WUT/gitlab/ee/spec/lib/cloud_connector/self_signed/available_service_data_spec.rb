# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::SelfSigned::AvailableServiceData, :saas, feature_category: :plan_provisioning do
  let(:cut_off_date) { 1.month.ago }
  let(:bundled_with) { {} }
  let(:backend) { 'gitlab-ai-gateway' }

  let_it_be(:cc_key) { create(:cloud_connector_keys) }
  let_it_be(:namespace) { create(:group) }
  let_it_be(:gitlab_add_on) { create(:gitlab_subscription_add_on) }
  let_it_be(:active_gitlab_purchase) do
    create(:gitlab_subscription_add_on_purchase, namespace: namespace, add_on: gitlab_add_on)
  end

  subject(:available_service_data) { described_class.new(:duo_chat, cut_off_date, bundled_with, backend) }

  describe '#access_token' do
    let(:encoded_token_string) { 'token_string' }
    let(:dc_unit_primitives) { [:duo_chat_up1, :duo_chat_up2] }
    let(:duo_pro_scopes) { dc_unit_primitives + [:duo_chat_up3] }
    let(:bundled_with) { { "duo_pro" => duo_pro_scopes } }

    let(:issuer) { 'gitlab.com' }
    let(:instance_id) { 'instance-uuid' }
    let(:gitlab_realm) { 'saas' }
    let(:ttl) { 1.hour }
    let(:exp) { 1.hour.from_now }
    let(:scopes) { [] }
    let(:extra_claims) { {} }

    let(:payload) do
      {
        sub: instance_id,
        iss: issuer,
        realm: gitlab_realm,
        aud: backend,
        exp: exp,
        scopes: scopes
      }
    end

    let(:expected_token) do
      instance_double('Gitlab::CloudConnector::JsonWebToken', encode: encoded_token_string, payload: payload)
    end

    subject(:access_token) { available_service_data.access_token(resource) }

    before do
      allow(Doorkeeper::OpenidConnect.configuration).to receive(:issuer).and_return(issuer)
      allow(Gitlab::CurrentSettings).to receive(:uuid).and_return(instance_id)
      allow(::CloudConnector).to receive(:gitlab_realm).and_return(gitlab_realm)
      allow(Gitlab::CloudConnector::JsonWebToken).to receive(:new).and_return(expected_token)
      # Ensure we do not write metrics to the file system
      allow(::Gitlab::Metrics).to receive(:counter).and_return(Gitlab::Metrics::NullMetric.instance)
    end

    shared_examples 'issue a token with scopes' do
      it 'returns the encoded token' do
        expect(Gitlab::CloudConnector::JsonWebToken).to receive(:new).with(
          issuer: issuer,
          audience: backend,
          subject: instance_id,
          realm: gitlab_realm,
          scopes: scopes,
          ttl: ttl,
          extra_claims: extra_claims
        ).and_return(expected_token)
        expect(expected_token).to receive(:encode).with(cc_key.to_jwk).and_return(encoded_token_string)

        expect(access_token).to eq(encoded_token_string)
      end

      it 'does not repeatedly load the validation key' do
        expect(::CloudConnector::Keys).to receive(:current)
          .at_most(:once)
          .and_return(cc_key)

        3.times { described_class.new(:duo_chat, cut_off_date, bundled_with, backend).access_token }
      end

      it 'logs the key load event once' do
        CloudConnector::CachingKeyLoader.instance_variable_set(:@jwk, nil)

        allow(::Gitlab::AppLogger).to receive(:info)

        3.times { described_class.new(:duo_chat, cut_off_date, bundled_with, backend).access_token }

        expect(::Gitlab::AppLogger).to have_received(:info).with(
          hash_including(
            message: /Cloud Connector key loaded/,
            cc_kid: cc_key.to_jwk.kid
          )
        ).once
      end

      it 'increments the token counter metric' do
        token_counter = instance_double(Prometheus::Client::Counter)
        expect(::Gitlab::Metrics).to receive(:counter)
          .with(:cloud_connector_tokens_issued_total, instance_of(String), worker_id: instance_of(String))
          .and_return(token_counter)
        expect(token_counter).to receive(:increment).with(
          a_hash_including(
            kid: cc_key.to_jwk.kid,
            operation_type: 'legacy',
            service_name: "duo_chat"
          )
        )

        access_token
      end
    end

    context 'when signing key is missing' do
      let(:resource) { namespace }
      let(:fake_key_loader) do
        Class.new(::CloudConnector::CachingKeyLoader) do
          def self.private_jwk
            load_key # don't actually cache the key
          end
        end
      end

      before do
        stub_const(
          'CloudConnector::CachingKeyLoader',
          fake_key_loader
        )
        allow(CloudConnector::Keys).to receive(:current).and_return(nil)
      end

      it 'raises NoSigningKeyError' do
        expect { access_token }.to raise_error(StandardError, 'Cloud Connector: no key found')
      end
    end

    context 'with free access' do
      let(:resource) { namespace }
      let(:cut_off_date) { nil }
      let(:scopes) { duo_pro_scopes }

      include_examples 'issue a token with scopes'
    end

    context 'when passing extra claims' do
      let(:resource) { namespace }
      let(:extra_claims) { { custom: 123 } }
      let(:scopes) { duo_pro_scopes }

      subject(:access_token) { available_service_data.access_token(resource, extra_claims: extra_claims) }

      include_examples 'issue a token with scopes'
    end

    context 'when passed resource is a User' do
      let(:resource) { create(:user) }

      context 'with duo_pro purchased' do
        context 'when user is part of the namespace' do
          let(:scopes) { duo_pro_scopes }

          before do
            namespace.add_member(resource, :developer)
          end

          include_examples 'issue a token with scopes'
        end
      end

      context 'when user is not part of the namespace' do
        let(:scopes) { [] }

        include_examples 'issue a token with scopes'
      end
    end

    context 'when passed resource is not a User' do
      let(:resource) { namespace }

      context 'with duo_pro purchased' do
        let(:scopes) { duo_pro_scopes }

        include_examples 'issue a token with scopes'
      end
    end
  end
end
