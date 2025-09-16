# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::AiConfigurationPresenter, feature_category: :ai_abstraction_layer do
  describe '#settings' do
    subject(:settings) { described_class.new.settings }

    let(:application_setting_attributes) do
      {
        disabled_direct_code_suggestions?: true,
        duo_availability: 'default_off',
        duo_chat_expiration_column: 'last_updated_at',
        duo_chat_expiration_days: '30',
        enabled_expanded_logging: true,
        gitlab_dedicated_instance?: false,
        instance_level_ai_beta_features_enabled: true,
        model_prompt_cache_enabled?: true
      }
    end

    let(:ai_settings_attributes) do
      {
        ai_gateway_url: 'http://localhost:3000',
        duo_core_features_enabled?: true
      }
    end

    let(:ai_settings) { instance_double(Ai::Setting, **ai_settings_attributes) }
    let(:any_add_on_purchase) { build(:gitlab_subscription_add_on_purchase, :duo_enterprise, :self_managed, :active) }
    let(:active_add_on_purchase_for_self_managed?) { true }
    let(:application_settings) { instance_double(ApplicationSetting, **application_setting_attributes) }
    let(:beta_self_hosted_models_enabled) { true }
    let(:self_hosted_models) { true }
    let(:active_duo_add_ons_exist?) { true }

    before do
      allow(GitlabSubscriptions::AddOnPurchase)
        .to receive(:active_duo_add_ons_exist?)
        .with(:instance)
        .and_return(active_duo_add_ons_exist?)

      allow(Ai::Setting).to receive(:instance).and_return(ai_settings)

      allow(Ai::TestingTermsAcceptance)
        .to receive(:has_accepted?)
        .and_return(beta_self_hosted_models_enabled)

      allow(License).to receive(:feature_available?).with(:self_hosted_models).and_return self_hosted_models

      allow(Gitlab::CurrentSettings).to receive(:current_application_settings).and_return application_settings

      allow(GitlabSubscriptions::DuoEnterprise).to receive_messages(
        active_add_on_purchase_for_self_managed?: active_add_on_purchase_for_self_managed?
      )
    end

    specify do
      expect(settings).to include(
        ai_gateway_url: 'http://localhost:3000',
        are_experiment_settings_allowed: 'true',
        are_prompt_cache_settings_allowed: 'true',
        beta_self_hosted_models_enabled: 'true',
        can_manage_self_hosted_models: 'true',
        disabled_direct_connection_method: 'true',
        duo_availability: 'default_off',
        duo_chat_expiration_column: 'last_updated_at',
        duo_chat_expiration_days: '30',
        duo_core_features_enabled: 'true',
        duo_pro_visible: 'true',
        enabled_expanded_logging: 'true',
        experiment_features_enabled: 'true',
        on_general_settings_page: 'false',
        prompt_cache_enabled: 'true',
        redirect_path: '/admin/gitlab_duo',
        toggle_beta_models_path: '/admin/ai/duo_self_hosted/toggle_beta_models'
      )
    end

    context 'with another ai_gateway_url' do
      let(:ai_settings_attributes) { super().merge(ai_gateway_url: 'https://example.com') }

      it { expect(settings).to include(ai_gateway_url: 'https://example.com') }
    end

    context 'without active Duo add-on' do
      let(:active_duo_add_ons_exist?) { false }

      it { expect(settings).to include(are_experiment_settings_allowed: 'false') }
      it { expect(settings).to include(duo_pro_visible: 'false') }
    end

    context 'with beta self-hosted models enabled' do
      let(:beta_self_hosted_models_enabled) { 'false' }

      it { expect(settings).to include(beta_self_hosted_models_enabled: 'false') }
    end

    context 'with Dedicated instance' do
      let(:application_setting_attributes) { super().merge(gitlab_dedicated_instance?: true) }

      it { expect(settings).to include(can_manage_self_hosted_models: 'false') }
    end

    context 'without self-hosted models license' do
      let(:self_hosted_models) { false }

      it { expect(settings).to include(can_manage_self_hosted_models: 'false') }
    end

    context 'without add-on purchase for Duo Enterprise' do
      let(:active_add_on_purchase_for_self_managed?) { false }

      it { expect(settings).to include(can_manage_self_hosted_models: 'false') }
    end

    context 'with enabled direct code suggestions' do
      let(:application_setting_attributes) { super().merge(disabled_direct_code_suggestions?: false) }

      it { expect(settings).to include(disabled_direct_connection_method: 'false') }
    end

    context 'with other Duo availability' do
      let(:application_setting_attributes) { super().merge(duo_availability: 'always_off') }

      it { expect(settings).to include(duo_availability: 'always_off') }
    end

    context 'with other Duo chat expiration column' do
      let(:application_setting_attributes) { super().merge(duo_chat_expiration_column: 'last_created_at') }

      it { expect(settings).to include(duo_chat_expiration_column: 'last_created_at') }
    end

    context 'with other Duo chat expiration days' do
      let(:application_setting_attributes) { super().merge(duo_chat_expiration_days: '10') }

      it { expect(settings).to include(duo_chat_expiration_days: '10') }
    end

    context 'without Duo Core features disabled' do
      let(:ai_settings_attributes) { super().merge(duo_core_features_enabled?: false) }

      it { expect(settings).to include(duo_core_features_enabled: 'false') }
    end

    context 'without expanded logging' do
      let(:application_setting_attributes) { super().merge(enabled_expanded_logging: false) }

      it { expect(settings).to include(enabled_expanded_logging: 'false') }
    end

    context 'without experiment features enabled' do
      let(:application_setting_attributes) { super().merge(instance_level_ai_beta_features_enabled: false) }

      it { expect(settings).to include(experiment_features_enabled: 'false') }
    end

    context 'without prompt cache' do
      let(:application_setting_attributes) { super().merge(model_prompt_cache_enabled?: false) }

      it { expect(settings).to include(prompt_cache_enabled: 'false') }
    end
  end
end
