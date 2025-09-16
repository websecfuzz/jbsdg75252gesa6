# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::BypassSettings, feature_category: :security_policy_management do
  let_it_be(:bypass_settings) do
    {
      access_tokens: [
        { id: 1 },
        { id: 2 }
      ],
      service_accounts: [
        { id: 10 },
        { id: 20 }
      ]
    }
  end

  subject(:bypass_settings_instance) { described_class.new(bypass_settings) }

  describe '#access_token_ids' do
    it 'returns the ids of access tokens' do
      expect(bypass_settings_instance.access_token_ids).to match_array([1, 2])
    end

    context 'when access_tokens is nil' do
      let_it_be(:bypass_settings) { {} }

      it 'returns nil' do
        expect(bypass_settings_instance.access_token_ids).to be_nil
      end
    end
  end

  describe '#service_account_ids' do
    it 'returns the ids of service accounts' do
      expect(bypass_settings_instance.service_account_ids).to match_array([10, 20])
    end

    context 'when service_accounts is nil' do
      let_it_be(:bypass_settings) { {} }

      it 'returns nil' do
        expect(bypass_settings_instance.service_account_ids).to be_nil
      end
    end
  end
end
