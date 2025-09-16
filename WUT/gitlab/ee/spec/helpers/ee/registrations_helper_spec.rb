# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::RegistrationsHelper, feature_category: :user_management do
  include Devise::Test::ControllerHelpers
  let(:expected_values) { UserDetail.onboarding_status_registration_objectives.values - [6] }

  describe '#shuffled_registration_objective_options' do
    subject(:shuffled_options) { helper.shuffled_registration_objective_options }

    it 'has values that match the UserDetail registration objective values' do
      shuffled_option_values = shuffled_options.map { |item| item.last }

      expect(shuffled_option_values).to contain_exactly(*expected_values)
    end

    it '"other" is always the last option' do
      expect(shuffled_options.last).to eq(['A different reason', 5])
    end
  end

  describe '#arkose_labs_data' do
    let(:request_double) { instance_double(ActionDispatch::Request) }
    let(:data_exchange_payload) { 'data_exchange_payload' }

    before do
      allow(helper).to receive(:request).and_return(request_double)

      allow(::AntiAbuse::IdentityVerification::Settings).to receive(:arkose_public_api_key).and_return('api-key')
      allow(::AntiAbuse::IdentityVerification::Settings).to receive(:arkose_labs_domain).and_return('domain')
      allow_next_instance_of(Arkose::DataExchangePayload, request_double,
        a_hash_including({ use_case: Arkose::DataExchangePayload::USE_CASE_SIGN_UP })) do |builder|
        allow(builder).to receive(:build).and_return(data_exchange_payload)
      end
    end

    subject(:data) { helper.arkose_labs_data }

    it 'contains the correct values' do
      expect(data).to eq({
        api_key: 'api-key',
        domain: 'domain',
        data_exchange_payload: data_exchange_payload,
        data_exchange_payload_path: data_exchange_payload_path
      })
    end

    context 'when data exchange payload is nil' do
      let(:data_exchange_payload) { nil }

      it 'does not include data_exchange_payload' do
        expect(data.keys).not_to include(:data_exchange_payload)
      end
    end
  end
end
