# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::HandRaiseLeadsController, feature_category: :subscription_management do
  describe 'POST /-/gitlab_subscriptions/hand_raise_leads' do
    let_it_be(:user) { create(:user, :with_namespace) }
    let_it_be(:namespace) { create(:group, developers: user) }
    let_it_be(:namespace_id) { namespace.id.to_s }

    let(:hand_raise_lead_result) { ServiceResponse.success }
    let(:post_params) do
      {
        namespace_id: namespace_id,
        first_name: 'James',
        last_name: 'Bond',
        company_name: 'ACME',
        phone_number: '+1-192-10-10',
        country: 'US',
        state: 'CA',
        comment: 'I want to talk to sales.',
        glm_content: 'group-billing',
        product_interaction: '_product_interaction_'
      }
    end

    subject(:post_hand_raise_lead) do
      post gitlab_subscriptions_hand_raise_leads_path, params: post_params
      response
    end

    before do
      stub_saas_features(gitlab_com_subscriptions: true)

      allow_next_instance_of(GitlabSubscriptions::CreateHandRaiseLeadService) do |service|
        allow(service).to receive(:execute).and_return(hand_raise_lead_result)
      end
    end

    context 'when authenticated' do
      before do
        sign_in(user)
      end

      it { is_expected.to have_gitlab_http_status(:ok) }

      it 'calls the hand raise lead service with correct parameters' do
        hand_raise_lead_extra_params =
          {
            work_email: user.email,
            uid: user.id,
            provider: 'gitlab',
            setup_for_company: user.onboarding_status_setup_for_company,
            existing_plan: namespace.actual_plan_name,
            glm_source: 'gitlab.com'
          }
        expect_next_instance_of(GitlabSubscriptions::CreateHandRaiseLeadService) do |service|
          expected_params = ActionController::Parameters.new(post_params)
                                                        .permit!
                                                        .merge(hand_raise_lead_extra_params)
          expect(service).to receive(:execute).with(expected_params).and_return(ServiceResponse.success)
        end

        post_hand_raise_lead
      end

      context 'when gitlab_com_subscriptions are not available' do
        before do
          stub_saas_features(gitlab_com_subscriptions: false)
        end

        it { is_expected.to have_gitlab_http_status(:not_found) }
      end

      context 'when namespace cannot be found' do
        let(:namespace_id) { non_existing_record_id.to_s }

        it { is_expected.to have_gitlab_http_status(:not_found) }
      end

      context 'with failure' do
        let(:hand_raise_lead_result) { ServiceResponse.error(message: '_fail_') }

        it { is_expected.to have_gitlab_http_status(:forbidden) }
      end
    end

    context 'when not authenticated' do
      it { is_expected.to have_gitlab_http_status(:not_found) }
    end
  end
end
