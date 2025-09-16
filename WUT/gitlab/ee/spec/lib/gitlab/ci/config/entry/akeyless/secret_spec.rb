# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Config::Entry::Akeyless::Secret, feature_category: :secrets_management do
  let(:entry) { described_class.new(config) }

  before do
    entry.compose!
  end

  describe 'validations' do
    context 'when all config value is correct' do
      let(:config) do
        {
          name: 'name',
          akeyless_access_key: nil,
          akeyless_access_type: nil,
          akeyless_api_url: nil,
          akeyless_token: nil,
          azure_object_id: nil,
          cert_user_name: nil,
          csr_data: nil,
          data_key: nil,
          gateway_ca_certificate: nil,
          gcp_audience: nil,
          k8s_auth_config_name: nil,
          k8s_service_account_token: nil,
          public_key_data: nil,
          uid_token: nil
        }
      end

      it { expect(entry).to be_valid }
    end

    context 'when config is nil' do
      let(:config) { nil }

      it { expect(entry).not_to be_valid }

      it 'reports error' do
        expect(entry.errors).to include(/secret config should be a hash/)
      end
    end

    context 'when only name is defined' do
      let(:config) do
        {
          name: 'name'
        }
      end

      it { expect(entry).to be_valid }
    end

    context 'when there is an unknown key present' do
      let(:config) { { foo: :bar } }

      it { expect(entry).not_to be_valid }

      it 'reports error' do
        expect(entry.errors)
          .to include 'secret config contains unknown keys: foo'
      end
    end

    context 'when config is not a hash' do
      let(:config) { "" }

      it { expect(entry).not_to be_valid }

      it 'reports error' do
        expect(entry.errors)
          .to include 'secret config should be a hash'
      end
    end
  end

  describe '#value' do
    context 'when config is valid' do
      let(:config) do
        {
          name: 'name',
          data_key: nil,
          cert_user_name: nil,
          public_key_data: nil,
          csr_data: nil,
          akeyless_api_url: nil,
          akeyless_access_type: nil,
          akeyless_token: nil,
          uid_token: nil,
          gcp_audience: nil,
          azure_object_id: nil,
          k8s_service_account_token: nil,
          k8s_auth_config_name: nil,
          akeyless_access_key: nil,
          gateway_ca_certificate: nil
        }
      end

      it 'returns config' do
        expect(entry.value).to eq(config)
      end
    end
  end
end
