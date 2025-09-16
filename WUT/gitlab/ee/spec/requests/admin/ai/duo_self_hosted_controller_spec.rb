# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::Ai::DuoSelfHostedController, :enable_admin_mode, feature_category: :"self-hosted_models" do
  let(:admin) { create(:admin) }
  let(:duo_features_enabled) { true }
  let_it_be(:license) { create(:license, plan: License::ULTIMATE_PLAN) }
  let_it_be(:add_on_purchase) do
    create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :active, :self_managed)
  end

  before do
    sign_in(admin)
    stub_ee_application_setting(duo_features_enabled: duo_features_enabled)
  end

  shared_examples 'returns 404' do
    context 'when the user is not authorized' do
      it 'performs the right authorization correctly' do
        allow(Ability).to receive(:allowed?).and_call_original
        expect(Ability).to receive(:allowed?).with(admin, :manage_self_hosted_models_settings).and_return(false)

        perform_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'GET #index' do
    let(:page) { Nokogiri::HTML(response.body) }

    subject :perform_request do
      get admin_ai_duo_self_hosted_path
    end

    it 'returns 200' do
      perform_request

      expect(response).to have_gitlab_http_status(:ok)
    end

    it_behaves_like 'returns 404'
  end
end
