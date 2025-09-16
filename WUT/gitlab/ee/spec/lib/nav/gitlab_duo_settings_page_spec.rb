# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Nav::GitlabDuoSettingsPage, feature_category: :duo_chat do
  using RSpec::Parameterized::TableSyntax

  include ::Nav::GitlabDuoSettingsPage

  let(:owner) { build_stubbed(:user, group_view: :security_dashboard) }
  let(:current_user) { owner }
  let(:group) { create(:group, :private) }

  describe '#show_gitlab_duo_settings_menu_item?' do
    where(:is_usage_quotas_enabled, :should_show_gitlab_duo_settings_app, :result) do
      true  | true  | true
      true  | false | false
      false | true  | false
      false | false | false
    end

    with_them do
      before do
        if should_show_gitlab_duo_settings_app
          stub_saas_features(gitlab_com_subscriptions: true)
          stub_licensed_features(code_suggestions: true)
          add_on = create(:gitlab_subscription_add_on)
          create(:gitlab_subscription_add_on_purchase, quantity: 50, namespace: group, add_on: add_on)
        end

        allow(group).to receive(:usage_quotas_enabled?) { is_usage_quotas_enabled }
      end

      it { expect(show_gitlab_duo_settings_menu_item?(group)).to be(result) }
    end
  end

  describe '#show_gitlab_duo_settings_app?' do
    context 'on saas' do
      let(:another_group) { build(:group) }

      before do
        stub_licensed_features(code_suggestions: true)
        stub_saas_features(gitlab_com_subscriptions: true)
        allow(group).to receive(:has_free_or_no_subscription?) { has_free_or_no_subscription? }
        create(:gitlab_subscription_add_on_purchase, :duo_pro, trial, namespace: group_with_duo_pro_trial)
      end

      where(:has_free_or_no_subscription?, :trial, :group_with_duo_pro_trial, :result) do
        true  | :trial         | ref(:another_group) | false
        false | :trial         | ref(:another_group) | true
        true  | :trial         | ref(:group)         | true
        false | :trial         | ref(:group)         | true
        true  | :expired_trial | ref(:group)         | true
        false | :expired_trial | ref(:group)         | true
      end

      with_them do
        it { expect(show_gitlab_duo_settings_app?(group)).to eq(result) }

        context 'when feature not available' do
          before do
            stub_licensed_features(code_suggestions: false)
          end

          it { expect(show_gitlab_duo_settings_app?(group)).to be_falsy }
        end
      end
    end

    context 'on self managed' do
      before do
        stub_licensed_features(code_suggestions: true)
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      it { expect(show_gitlab_duo_settings_app?(group)).to be_falsy }
    end
  end
end
