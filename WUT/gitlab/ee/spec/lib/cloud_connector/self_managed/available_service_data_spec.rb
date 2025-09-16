# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::SelfManaged::AvailableServiceData, feature_category: :plan_provisioning do
  describe '#access_token' do
    subject(:access_token) { described_class.new(:duo_chat, nil, nil).access_token(nil) }

    let_it_be(:older_active_token) { create(:service_access_token, :active) }
    let_it_be(:newer_active_token) { create(:service_access_token, :active) }
    let_it_be(:inactive_token) { create(:service_access_token, :expired) }

    it { is_expected.to eq(newer_active_token.token) }
  end
end
