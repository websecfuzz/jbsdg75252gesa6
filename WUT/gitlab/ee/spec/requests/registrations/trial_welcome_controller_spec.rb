# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Registrations::TrialWelcomeController, :saas, feature_category: :onboarding do
  let_it_be(:user) { create(:user) }
  let(:glm_params) { { glm_source: '_glm_source_', glm_content: '_glm_content_' } }

  describe 'GET #new' do
    let(:base_params) { glm_params }

    subject(:get_new) do
      get new_users_sign_up_trial_welcome_path, params: base_params
      response
    end

    context 'when not authenticated' do
      it { is_expected.to have_gitlab_http_status(:redirect) }
    end

    context 'when authenticated' do
      before do
        sign_in(user)
      end

      it { is_expected.to have_gitlab_http_status(:ok) }

      it 'enables dark mode' do
        get_new

        expect(assigns(:html_class)).to eq('gl-dark')
      end
    end
  end
end
