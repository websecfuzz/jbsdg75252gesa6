# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Profiles::AccountsController do
  describe 'DELETE unlink' do
    let(:user) { create(:omniauth_user) }

    before do
      sign_in(user)
    end

    it 'renders 404 if someone tries to unlink a non existent provider' do
      delete :unlink, params: { provider: 'github' }

      expect(response).to have_gitlab_http_status(:not_found)
    end

    describe "saml provider" do
      let(:user) { create(:omniauth_user, provider: 'saml') }

      it "does not allow to unlink connected account" do
        identity = user.identities.last

        delete :unlink, params: { provider: 'saml' }

        expect(response).to have_gitlab_http_status(:found)
        expect(user.reload.identities).to include(identity)
      end
    end

    [:twitter, :google_oauth2, :gitlab, :github, :bitbucket, :crowd, :auth0, :alicloud].each do |provider|
      describe "#{provider} provider" do
        let(:user) { create(:omniauth_user, provider: provider.to_s) }

        it 'allows to unlink connected account' do
          identity = user.identities.last

          delete :unlink, params: { provider: provider.to_s }

          expect(response).to have_gitlab_http_status(:found)
          expect(user.reload.identities).not_to include(identity)
        end
      end
    end

    describe 'atlassian_oauth2 provider' do
      let(:user) { create(:atlassian_user) }

      it 'allows a user to unlink a connected account' do
        expect(user.atlassian_identity).not_to be_nil

        delete :unlink, params: { provider: 'atlassian_oauth2' }

        expect(response).to have_gitlab_http_status(:found)
        expect(user.reload.atlassian_identity).to be_nil
      end
    end
  end

  describe 'POST #generate_support_pin' do
    let(:user) { create(:user) }

    before do
      sign_in(user)
    end

    it 'generates a new Support PIN successfully' do
      expect(Users::SupportPin::UpdateService).to receive(:new).with(user).and_call_original

      post :generate_support_pin

      expect(response).to redirect_to(profile_account_path)
      expect(flash[:notice]).to eq('New Support PIN generated successfully.')
    end

    it 'handles failure to generate Support PIN' do
      allow_next_instance_of(Users::SupportPin::UpdateService) do |instance|
        allow(instance).to receive(:execute).and_return({ status: :error })
      end

      post :generate_support_pin

      expect(response).to redirect_to(profile_account_path)
      expect(flash[:alert]).to eq('Failed to generate new Support PIN.')
    end
  end
end
