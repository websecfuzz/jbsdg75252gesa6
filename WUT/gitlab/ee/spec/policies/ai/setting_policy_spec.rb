# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::SettingPolicy, :enable_admin_mode, feature_category: :"self-hosted_models" do
  subject(:policy) { described_class.new(current_user, duo_settings) }

  let_it_be(:duo_settings) { create(:ai_settings, duo_core_features_enabled: true) }
  let_it_be_with_reload(:current_user) { create(:admin) }

  let_it_be(:license) { create(:license, plan: License::ULTIMATE_PLAN) }
  let_it_be_with_reload(:add_on_purchase) do
    create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :active, :self_managed)
  end

  describe 'read_self_hosted_models_settings' do
    context 'when user is not authorized to manage Duo self-hosted settings' do
      before do
        add_on_purchase.update!(expires_on: Date.yesterday)
      end

      it { is_expected.to be_disallowed(:read_self_hosted_models_settings) }
    end

    context 'when user is authorized to manage Duo self-hosted settings' do
      it { is_expected.to be_allowed(:read_self_hosted_models_settings) }
    end
  end

  describe 'read_duo_core_settings' do
    context 'when user is nil' do
      let!(:current_user) { nil }

      it { is_expected.to be_disallowed(:read_duo_core_settings) }
    end

    context 'when user is not authorized to manage Duo Core settings' do
      before do
        stub_licensed_features(code_suggestions: false, ai_chat: false)
      end

      it { is_expected.to be_disallowed(:read_duo_core_settings) }
    end

    context 'when user is authorized to manage Duo Core settings' do
      it { is_expected.to be_allowed(:read_duo_core_settings) }
    end
  end
end
