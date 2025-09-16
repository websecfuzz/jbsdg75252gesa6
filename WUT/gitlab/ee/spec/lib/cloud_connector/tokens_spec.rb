# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::Tokens, feature_category: :system_access do
  describe '.get' do
    let(:resource) { build(:user) }
    let(:token_string) { 'ABCDEF' }
    let(:extra_claims) { {} }

    subject(:encoded_token) do
      described_class.get(
        unit_primitive: unit_primitive,
        resource: resource,
        extra_claims: extra_claims
      )
    end

    before do
      # "Defuse" all counter calls so as not to pollute the tmp folder with metric data.
      allow(::Gitlab::Metrics).to receive(:counter).and_return(Gitlab::Metrics::NullMetric.instance)
    end

    shared_examples 'uses TokenLoader to obtain a token' do
      let(:token_provider) { instance_double(described_class::TokenLoader, token: token_string) }

      before do
        allow(described_class::TokenLoader).to receive(:new).and_return(token_provider)
      end

      it 'returns the token from TokenLoader' do
        expect(encoded_token).to eq(token_string)
      end
    end

    shared_examples 'uses AvailableServices legacy path' do
      it 'calls legacy service.access_token' do
        service = instance_double(CloudConnector::SelfSigned::AvailableServiceData)
        allow(CloudConnector::AvailableServices).to receive(:find_by_name).with(unit_primitive).and_return(service)
        expect(service).to receive(:access_token).with(resource, extra_claims: extra_claims).and_return(token_string)

        expect(encoded_token).to eq(token_string)
      end
    end

    shared_examples 'uses self-signed path' do
      let_it_be(:jwk) { build(:cloud_connector_keys).to_jwk }
      let_it_be(:add_on_purchase) { build(:gitlab_subscription_add_on_purchase, :duo_pro, :self_managed, :active) }

      before do
        allow_next_instance_of(described_class::TokenIssuer) do |issuer|
          allow(issuer).to receive(:token).and_return(token_string)
        end

        allow(CloudConnector::CachingKeyLoader).to receive(:private_jwk).and_return(jwk)
      end

      it 'returns a self-signed token' do
        expect(encoded_token).to eq(token_string)
      end
    end

    context 'when self-signed tokens are globally enabled via SaaS feature flag' do
      before do
        stub_saas_features(cloud_connector_self_signed_tokens: true)
      end

      context 'with fully rolled out unit primitive' do
        let(:unit_primitive) { :observability_all }

        it_behaves_like 'uses self-signed path'
      end

      context 'with unknown unit primitive' do
        let(:unit_primitive) { :not_rolled_out }

        it_behaves_like 'uses AvailableServices legacy path'
      end

      context 'with nil unit primitive' do
        let(:unit_primitive) { nil }

        it_behaves_like 'uses AvailableServices legacy path'
      end
    end

    context 'when self_hosted model is configured for the feature' do
      let(:unit_primitive) { :observability_all }

      before do
        feature_obj = instance_double(Ai::FeatureSetting, self_hosted?: true)
        allow(Ai::FeatureSetting).to receive(:feature_for_unit_primitive).with(unit_primitive).and_return(feature_obj)
      end

      it_behaves_like 'uses self-signed path'
    end

    context 'when environment variable is set' do
      let(:unit_primitive) { :observability_all }

      before do
        stub_env('CLOUD_CONNECTOR_SELF_SIGN_TOKENS', 'true')
      end

      it_behaves_like 'uses self-signed path'
    end

    context 'when none of the self-signing conditions are met' do
      context 'and feature_for_unit_primitive returns nil' do
        let(:unit_primitive) { :observability_all }

        before do
          allow(Ai::FeatureSetting).to receive(:feature_for_unit_primitive).with(unit_primitive).and_return(nil)
        end

        it_behaves_like 'uses TokenLoader to obtain a token'
      end

      context 'and unit_primitive is unknown' do
        let(:unit_primitive) { :unknown }

        it_behaves_like 'uses TokenLoader to obtain a token'
      end
    end
  end
end
