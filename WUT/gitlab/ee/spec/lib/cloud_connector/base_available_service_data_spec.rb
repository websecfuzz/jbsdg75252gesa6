# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::BaseAvailableServiceData, feature_category: :plan_provisioning do
  let(:namespace) { active_gitlab_purchase.namespace }
  let(:service_name) { :my_service }
  let_it_be(:cut_off_date) { 1.day.ago }
  let_it_be(:purchased_add_ons) { %w[duo_pro] }
  let_it_be(:user) { create(:user) }
  let_it_be(:gitlab_add_on) { create(:gitlab_subscription_add_on) }
  let_it_be(:expired_gitlab_purchase) do
    create(:gitlab_subscription_add_on_purchase, expires_on: 1.day.ago, add_on: gitlab_add_on)
  end

  let_it_be_with_reload(:active_gitlab_purchase) do
    create(:gitlab_subscription_add_on_purchase, add_on: gitlab_add_on)
  end

  subject(:service_data) { described_class.new(service_name, cut_off_date, purchased_add_ons) }

  describe '#free_access?' do
    subject(:free_access) { service_data.free_access? }

    context 'when cut_off_date is in the past' do
      let_it_be(:cut_off_date) { 1.day.ago }

      it { is_expected.to be false }
    end

    context 'when cut_off_date is in the future' do
      let_it_be(:cut_off_date) { 1.day.from_now }

      it { is_expected.to be true }
    end
  end

  describe '#name' do
    subject(:name) { service_data.name }

    it { is_expected.to eq(service_name) }
  end

  describe '#access_token' do
    subject(:access_token) { service_data.access_token(nil) }

    it 'raises not implemented exception' do
      expect { access_token }.to raise_error('Not implemented')
    end
  end
end
