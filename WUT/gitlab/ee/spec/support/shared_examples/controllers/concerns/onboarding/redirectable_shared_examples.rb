# frozen_string_literal: true

RSpec.shared_examples EE::Onboarding::Redirectable do |registration_type|
  context 'when onboarding is enabled' do
    before do
      stub_saas_features(onboarding: true)
    end

    it 'onboards the user' do
      post_create

      expect(response).to redirect_to(users_sign_up_welcome_path)
      created_user = User.find_by_email(new_user_email)
      expect(created_user).to be_onboarding_in_progress
      expect(created_user.onboarding_status_step_url).to eq(users_sign_up_welcome_path)
      expect(created_user.onboarding_status_initial_registration_type).to eq(registration_type)
      expect(created_user.onboarding_status_registration_type).to eq(registration_type)
      expect(created_user.onboarding_status_email_opt_in).to be(true)
      expect(created_user.onboarding_status_glm_content).to eq('_glm_content_')
      expect(created_user.onboarding_status_glm_source).to eq('_glm_source_')
    end

    context 'with onboarding_status_email_opt_in passed as false' do
      let(:extra_params) { { onboarding_status_email_opt_in: 'false' } }

      it 'stores the onboarding_status_email_opt_in' do
        post_create

        created_user = User.find_by_email(new_user_email)
        expect(created_user.onboarding_status_email_opt_in).to be(false)
      end
    end

    context 'with onboarding_status_email_opt_in passed as non boolean' do
      let(:extra_params) { { onboarding_status_email_opt_in: nil } }

      it 'stores the onboarding_status_email_opt_in' do
        post_create

        created_user = User.find_by_email(new_user_email)
        expect(created_user.onboarding_status_email_opt_in).to be(false)
      end
    end

    context 'with onboarding_status_email_opt_in passed not present' do
      let(:extra_params) { {} }

      it 'stores the onboarding_status_email_opt_in' do
        post_create

        created_user = User.find_by_email(new_user_email)
        expect(created_user.onboarding_status_email_opt_in).to be_nil
      end
    end
  end

  context 'when onboarding is disabled' do
    before do
      stub_saas_features(onboarding: false)
    end

    it 'does not onboard the user' do
      post_create

      expect(response).not_to redirect_to(users_sign_up_welcome_path)
      created_user = User.find_by_email(new_user_email)
      expect(created_user).not_to be_onboarding_in_progress
      expect(created_user.onboarding_status_step_url).to be_nil
      expect(created_user.onboarding_status_email_opt_in).to be_nil
    end
  end
end
