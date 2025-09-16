# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::HandRaiseLeadsHelper, feature_category: :acquisition do
  describe '#hand_raise_modal_dataset' do
    it 'provides the expected dataset' do
      user = build_stubbed(:user)
      root_namespace = build_stubbed(:namespace)
      allow(helper).to receive(:current_user).and_return(user)
      result = {
        user: {
          namespace_id: root_namespace.id,
          user_name: user.username,
          first_name: user.first_name,
          last_name: user.last_name,
          company_name: user.user_detail_organization
        }.to_json,
        submit_path: gitlab_subscriptions_hand_raise_leads_path
      }

      expect(helper.hand_raise_modal_dataset(root_namespace)).to eq(result)
    end
  end

  describe '#discover_page_hand_raise_lead_data' do
    it 'provides the expected dataset' do
      result = {
        glm_content: 'trial_discover_page',
        cta_tracking: {
          action: 'click_contact_sales',
          label: 'trial_expired'
        }.to_json,
        button_attributes: {
          variant: 'confirm',
          category: 'secondary',
          'data-testid': 'trial-discover-hand-raise-lead-button',
          class: 'gl-w-full sm:gl-w-auto'
        }.to_json
      }

      expect(helper.discover_page_hand_raise_lead_data(build_stubbed(:group))).to eq(result)
    end
  end

  describe '#free_plan_billing_hand_raise_lead_data' do
    it 'provides the expected dataset' do
      result = {
        glm_content: 'billing-group',
        button_text: s_("BillingPlans|Talk to an expert"),
        cta_tracking: { action: 'click_button' }.to_json,
        button_attributes: {
          category: 'secondary',
          class: 'gl-align-text-bottom'
        }.to_json
      }

      expect(helper.free_plan_billing_hand_raise_lead_data).to eq(result)
    end
  end

  describe '#code_suggestions_usage_app_hand_raise_lead_data' do
    it 'provides the expected dataset' do
      result = {
        glm_content: 'code-suggestions',
        product_interaction: 'Requested Contact-Duo Pro Add-On',
        cta_tracking: {
          action: 'click_button',
          label: 'code_suggestions_hand_raise_lead_form'
        }.to_json,
        button_attributes: {
          'data-testid': 'code-suggestions-hand-raise-lead-button',
          category: 'secondary',
          variant: 'confirm',
          class: 'sm:gl-w-auto gl-w-full sm:gl-ml-3 sm:gl-mt-0 gl-mt-3'
        }.to_json
      }

      expect(helper.code_suggestions_usage_app_hand_raise_lead_data).to eq(result)
    end
  end

  describe '#billing_action_hand_raise_lead_data' do
    it 'provides the expected dataset' do
      result = {
        glm_content: 'billing-group',
        cta_tracking: { action: 'click_link', property: 'code' }.to_json,
        button_attributes: {}.to_json
      }

      expect(helper.billing_action_hand_raise_lead_data('code')).to eq(result)
    end
  end

  describe 'discover_duo_pro_hand_raise_lead_data' do
    let_it_be(:namespace) { build_stubbed(:group) }

    describe 'discover_duo_pro_hand_raise_lead_data' do
      let(:namespace) { build_stubbed(:group) }

      it 'provides the expected dataset' do
        expected_label = helper.duo_pro_trial_status_cta_label(namespace)

        result = {
          namespace_id: namespace.id,
          glm_content: 'discover-duo-pro',
          cta_tracking: {
            action: 'click_contact_sales',
            label: expected_label
          }.to_json,
          button_attributes: {
            category: 'secondary',
            variant: 'confirm',
            class: 'gl-w-full sm:gl-w-auto'
          }.to_json
        }

        expect(helper.discover_duo_pro_hand_raise_lead_data(namespace)).to eq(result)
      end
    end

    describe '#group_trial_status' do
      let_it_be(:group) { build_stubbed(:group) }

      context 'when trial is active' do
        before do
          allow(group).to receive(:trial_active?).and_return(true)
        end

        it 'returns correct status' do
          expect(helper.group_trial_status(group)).to eq 'trial_active'
        end
      end

      context 'when trial is expired' do
        before do
          allow(group).to receive(:trial_active?).and_return(false)
        end

        it 'returns correct status' do
          expect(helper.group_trial_status(group)).to eq 'trial_expired'
        end
      end
    end

    describe '#duo_pro_trial_status_cta_label' do
      let(:namespace) { build_stubbed(:namespace) }

      context 'when an active trial DuoPro add-on purchase exists' do
        before do
          allow(GitlabSubscriptions::Trials::DuoPro).to receive(:active_add_on_purchase_for_namespace?)
            .with(namespace).and_return(true)
        end

        it 'returns the active trial label' do
          expect(helper.duo_pro_trial_status_cta_label(namespace)).to eq('duo_pro_active_trial')
        end
      end

      context 'when an expired trial DuoPro add-on purchase exists' do
        before do
          allow(GitlabSubscriptions::Trials::DuoPro).to receive(:active_add_on_purchase_for_namespace?)
            .with(namespace).and_return(false)
        end

        it 'returns the expired trial label' do
          expect(helper.duo_pro_trial_status_cta_label(namespace)).to eq('duo_pro_expired_trial')
        end
      end
    end
  end
end
