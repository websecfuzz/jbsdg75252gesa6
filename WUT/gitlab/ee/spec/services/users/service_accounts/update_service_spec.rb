# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::ServiceAccounts::UpdateService, feature_category: :user_management do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:admin) { create(:admin) }
  let_it_be(:service_account_user) { create(:user, :service_account) }
  let_it_be(:regular_user) { create(:user) }

  let_it_be(:user) { service_account_user }

  let_it_be(:params) do
    {
      name: FFaker::Name.name,
      username: FFaker::Internet.unique.user_name,
      email: FFaker::Internet.email
    }
  end

  subject(:result) { described_class.new(current_user, user, params).execute }

  shared_examples 'not authorized to update' do
    it 'returns an error', :aggregate_failures do
      expect(result.status).to eq(:error)
      expect(result.message).to eq(s_('ServiceAccount|User does not have permission to update a service account.'))
      expect(result.reason).to eq(:forbidden)
    end
  end

  shared_examples 'authorized to update' do
    it 'updates the service account', :aggregate_failures do
      expect(result.status).to eq(:success)
      expect(result.message).to eq(_('Service account was successfully updated.'))
      expect(result.payload[:user]).to eq(service_account_user)
      expect(result.payload[:user].name).to eq(params[:name])
      expect(result.payload[:user].username).to eq(params[:username])
      expect(result.payload[:user].email).to eq(params[:email])
    end

    context 'when the ability to update name for users is disabled' do
      before do
        stub_application_setting(updating_name_disabled_for_users: true)
      end

      it 'updates the service account name', :aggregate_failures do
        expect(result.status).to eq(:success)
        expect(result.message).to eq(_('Service account was successfully updated.'))
        expect(result.payload[:user]).to eq(service_account_user)
        expect(result.payload[:user].name).to eq(params[:name])
      end
    end

    context 'when user is not a service account' do
      let(:user) { regular_user }

      it 'returns an error', :aggregate_failures do
        expect(result.status).to eq(:error)
        expect(result.message).to eq('User is not a service account')
        expect(result.reason).to eq(:bad_request)
      end
    end

    context 'when params are empty' do
      let(:params) { {} }

      it 'returns success', :aggregate_failures do
        expect(result.status).to eq(:success)
        expect(result.message).to eq(_('Service account was successfully updated.'))
      end
    end

    context 'when username is already taken' do
      let(:existing_user) { create(:user, username: 'existing_username') }
      let(:params) { { username: existing_user.username } }

      it 'returns an error', :aggregate_failures do
        expect(result.status).to eq(:error)
        expect(result.message).to include('Username has already been taken')
        expect(result.reason).to eq(:bad_request)
      end
    end

    context 'when user update fails' do
      before do
        allow_next_instance_of(Users::UpdateService) do |update_service|
          allow(update_service).to receive(:execute).and_return(ServiceResponse.error(message: 'Update failed'))
        end
      end

      it 'returns an error', :aggregate_failures do
        expect(result.status).to eq(:error)
        expect(result.message).to eq('Update failed')
        expect(result.reason).to eq(:bad_request)
      end
    end
  end

  context 'when feature is licensed' do
    before do
      stub_licensed_features(service_accounts: true)
    end

    context 'when current user is an admin' do
      let(:current_user) { admin }

      context 'when admin mode is not enabled' do
        it_behaves_like 'not authorized to update'
      end

      context 'when admin mode is enabled', :enable_admin_mode do
        it_behaves_like 'authorized to update'

        context 'when email confirmation setting is set to hard' do
          before do
            stub_application_setting_enum('email_confirmation_setting', 'hard')
          end

          let(:params) { super().merge(email: 'new-email@email.com') }

          it 'updates the unconfirmed email instead of the email', :aggregate_failures do
            expect(result.payload[:user].unconfirmed_email).to eq(params[:email])
            expect(result.payload[:user].email).not_to eq(params[:email])
          end
        end
      end
    end

    context 'when current user is not an admin' do
      before do
        group = create(:group)
        group.add_owner(current_user)
      end

      let(:current_user) { create(:user) }

      it_behaves_like 'not authorized to update'
    end
  end

  context 'when feature is not licensed' do
    before do
      stub_licensed_features(service_accounts: false)
    end

    context 'when current user is an admin' do
      let(:current_user) { admin }

      context 'when admin mode is enabled', :enable_admin_mode do
        it_behaves_like 'not authorized to update'
      end
    end
  end
end
