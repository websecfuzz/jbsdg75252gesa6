# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::AiPresenter, feature_category: :ai_abstraction_layer do
  include SubscriptionPortalHelper

  describe '#settings' do
    subject(:settings) { described_class.new.settings }

    let(:application_setting_attributes) do
      {
        disabled_direct_code_suggestions?: false,
        duo_availability: 'default_off',
        enabled_expanded_logging: true,
        gitlab_dedicated_instance?: false,
        instance_level_ai_beta_features_enabled?: true,
        model_prompt_cache_enabled?: true
      }
    end

    let(:ai_settings_attributes) do
      {
        ai_gateway_url: 'http://localhost:3000',
        amazon_q_ready?: true,
        duo_core_features_enabled?: true,
        duo_workflow_service_account_user: {
          id: 1,
          username: 'admin',
          name: 'Administrator',
          avatar_url: 'http://localhost:3000/uploads/avatar.png'
        }
      }
    end

    let(:license) do
      build(
        :license,
        expires_at: subscription_end_date,
        starts_at: subscription_start_date,
        data: build(
          :gitlab_license,
          restrictions: {
            subscription_name: subscription_name
          }
        ).export
      )
    end

    let(:ai_settings) { instance_double(Ai::Setting, **ai_settings_attributes) }
    let(:amazon_q_available?) { true }
    let(:any_add_on_purchase) { build(:gitlab_subscription_add_on_purchase, :duo_enterprise, :self_managed, :active) }
    let(:active_add_on_purchase_for_self_managed?) { true }
    let(:active_self_managed_duo_pro_or_enterprise) { any_add_on_purchase }
    let(:auto_review_enabled) { true }
    let(:beta_self_hosted_models_enabled) { true }
    let(:duo_workflow_enabled) { true }
    let(:is_saas) { true }
    let(:self_hosted_models) { true }
    let(:subscription_end_date) { 1.year.from_now.to_date }
    let(:subscription_start_date) { 1.year.ago.to_date }
    let(:subscription_name) { 'A-S0000001' }
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

      allow(License).to receive(:current).and_return license

      allow(Gitlab::CurrentSettings)
        .to receive_messages(
          current_application_settings: instance_double(ApplicationSetting, **application_setting_attributes),
          slack_app_enabled: true
        )

      allow(GitlabSubscriptions::DuoEnterprise).to receive_messages(
        active_add_on_purchase_for_self_managed?: active_add_on_purchase_for_self_managed?
      )

      allow(GitlabSubscriptions::Duo).to receive_messages(
        active_self_managed_duo_pro_or_enterprise: active_self_managed_duo_pro_or_enterprise
      )

      allow(Ai::DuoWorkflow).to receive(:available?).and_return duo_workflow_enabled

      stub_saas_features(gitlab_com_subscriptions: is_saas)

      allow(Ai::AmazonQ).to receive(:feature_available?).and_return amazon_q_available?
      allow(Integrations::AmazonQ).to receive(:for_instance)
        .and_return [instance_double(Integrations::AmazonQ, auto_review_enabled: auto_review_enabled)]

      stub_env('CUSTOMER_PORTAL_URL', nil)
    end

    specify do
      expect(settings).to include(
        add_duo_pro_seats_url: "#{staging_customers_url}/gitlab/subscriptions/A-S0000001/duo_pro_seats",
        ai_gateway_url: 'http://localhost:3000',
        amazon_q_auto_review_enabled: 'true',
        amazon_q_configuration_path: '/admin/application_settings/integrations/amazon_q/edit',
        amazon_q_ready: 'true',
        are_duo_core_features_enabled: 'true',
        are_experiment_settings_allowed: 'true',
        are_prompt_cache_settings_allowed: 'true',
        beta_self_hosted_models_enabled: 'true',
        can_manage_self_hosted_models: 'true',
        direct_code_suggestions_enabled: 'true',
        duo_workflow_service_account: {
          id: 1,
          username: 'admin',
          name: 'Administrator',
          avatar_url: 'http://localhost:3000/uploads/avatar.png'
        }.to_json,
        duo_add_on_end_date: any_add_on_purchase.expires_on,
        duo_add_on_start_date: any_add_on_purchase.started_at,
        duo_availability: 'default_off',
        duo_configuration_path: '/admin/gitlab_duo/configuration',
        duo_seat_utilization_path: '/admin/gitlab_duo/seat_utilization',
        duo_self_hosted_path: '/admin/ai/duo_self_hosted',
        duo_workflow_disable_path: '/admin/ai/duo_workflow_settings/disconnect',
        duo_workflow_enabled: 'true',
        duo_workflow_settings_path: '/admin/ai/duo_workflow_settings',
        enabled_expanded_logging: 'true',
        experiment_features_enabled: 'true',
        is_bulk_add_on_assignment_enabled: 'true',
        is_saas: 'true',
        prompt_cache_enabled: 'true',
        redirect_path: '/admin/gitlab_duo',
        subscription_end_date: subscription_end_date,
        subscription_name: 'A-S0000001',
        subscription_start_date: subscription_start_date
      )
    end

    context 'with another subscription name' do
      let(:subscription_name) { 'A-S0000002' }

      it { expect(settings).to include(subscription_name: 'A-S0000002') }
    end

    context 'with another ai_gateway_url' do
      let(:ai_settings_attributes) { super().merge(ai_gateway_url: 'https://example.com') }

      it { expect(settings).to include(ai_gateway_url: 'https://example.com') }
    end

    context 'with auto review unset' do
      let(:auto_review_enabled) { nil }

      it { expect(settings).to include(amazon_q_auto_review_enabled: 'false') }
    end

    context 'with auto review disabled' do
      let(:auto_review_enabled) { false }

      it { expect(settings).to include(amazon_q_auto_review_enabled: 'false') }
    end

    context 'without Amazon Q ready' do
      let(:ai_settings_attributes) { super().merge(amazon_q_ready?: false) }

      it { expect(settings).to include(amazon_q_ready: 'false') }
    end

    context 'without Duo Core features disabled' do
      let(:ai_settings_attributes) { super().merge(duo_core_features_enabled?: false) }

      it { expect(settings).to include(are_duo_core_features_enabled: 'false') }
    end

    context 'without active Duo add-on' do
      let(:active_duo_add_ons_exist?) { false }

      it { expect(settings).to include(are_experiment_settings_allowed: 'false') }
    end

    context 'with beta_self_hosted_models_enabled' do
      let(:beta_self_hosted_models_enabled) { 'false' }

      it { expect(settings).to include(beta_self_hosted_models_enabled: 'false') }
    end

    context 'with Dedicated instance' do
      let(:application_setting_attributes) { super().merge(gitlab_dedicated_instance?: true) }

      it { expect(settings).to include(can_manage_self_hosted_models: 'false') }
    end

    context 'without self_hosted_models license' do
      let(:self_hosted_models) { false }

      it { expect(settings).to include(can_manage_self_hosted_models: 'false') }
    end

    context 'without add-on purchase for Duo Enterprise' do
      let(:active_add_on_purchase_for_self_managed?) { false }

      it { expect(settings).to include(can_manage_self_hosted_models: 'false') }
    end

    context 'without add-on purchase for Duo Pro or Duo Enterprise' do
      let(:active_self_managed_duo_pro_or_enterprise) { nil }

      it { expect(settings).to include(duo_add_on_end_date: nil, duo_add_on_start_date: nil) }
    end

    context 'with disabled direct code suggestions' do
      let(:application_setting_attributes) { super().merge(disabled_direct_code_suggestions?: true) }

      it { expect(settings).to include(direct_code_suggestions_enabled: 'false') }
    end

    context 'without service account' do
      let(:ai_settings_attributes) { super().merge(duo_workflow_service_account_user: nil) }

      it { expect(settings).to include(duo_workflow_service_account: nil) }
    end

    context 'with other Duo availability' do
      let(:application_setting_attributes) { super().merge(duo_availability: 'always_off') }

      it { expect(settings).to include(duo_availability: 'always_off') }
    end

    context 'without Duo workflow' do
      let(:duo_workflow_enabled) { false }

      it { expect(settings).to include(duo_workflow_enabled: 'false') }
    end

    context 'without expanded logging' do
      let(:application_setting_attributes) { super().merge(enabled_expanded_logging: false) }

      it { expect(settings).to include(enabled_expanded_logging: 'false') }
    end

    context 'with Self-Managed' do
      let(:is_saas) { false }

      it { expect(settings).to include(is_saas: 'false') }
    end

    context 'without prompt cache' do
      let(:application_setting_attributes) { super().merge(model_prompt_cache_enabled?: false) }

      it { expect(settings).to include(prompt_cache_enabled: 'false') }
    end

    context 'with expired license' do
      let(:subscription_end_date) { 1.day.ago }

      it { expect(settings).to include(subscription_end_date: 1.day.ago.to_date) }
    end

    context 'with future license' do
      let(:subscription_start_date) { 1.day.from_now }

      it { expect(settings).to include(subscription_start_date: 1.day.from_now.to_date) }
    end
  end
end
