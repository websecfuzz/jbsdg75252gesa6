# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::ServiceAccounts::UpdateService, feature_category: :user_management do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:other_group) { create(:group, organization: organization) }
  let(:group) { create(:group, organization: organization) }
  let(:admin) { create(:admin) }
  let(:owner) { create(:user) }
  let(:maintainer) { create(:user) }
  let(:service_account_user) { create(:user, :service_account, provisioned_by_group: group) }
  let(:regular_user) { create(:user, provisioned_by_group: group) }

  let(:user) { service_account_user }

  let(:params) do
    {
      name: FFaker::Name.name,
      username: FFaker::Internet.unique.user_name,
      email: FFaker::Internet.email,
      group_id: group.id
    }
  end

  let(:current_user) { owner }

  subject(:result) { described_class.new(current_user, user, params).execute }

  before do
    group.add_owner(owner)
    group.add_maintainer(maintainer)
  end

  shared_examples 'not authorized to update' do
    it 'returns an error', :aggregate_failures do
      expect(result.status).to eq(:error)
      expect(result.message).to eq(
        s_('ServiceAccount|You are not authorized to update service accounts in this namespace.')
      )
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

      it 'returns an error', :aggregate_failures do
        expect(result.status).to eq(:error)
        expect(result.message).to eq(_('Group with the provided ID not found.'))
      end
    end

    context 'when the provided group id is invalid' do
      let(:params) { super().merge(group_id: other_group.id) }

      it 'returns an error', :aggregate_failures do
        expect(result.status).to eq(:error)
        expect(result.message).to eq(_('Group ID provided does not match the service account\'s group ID.'))
      end
    end

    context 'when username is already taken' do
      let(:existing_user) { create(:user, username: 'existing_username') }
      let(:params) { super().merge({ username: existing_user.username }) }

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
      end
    end

    context 'when current user is a group owner' do
      let(:current_user) { owner }

      it_behaves_like 'authorized to update'

      context 'when saas', :saas do
        it_behaves_like 'authorized to update'
      end

      context 'when email confirmation setting is set to hard' do
        before do
          stub_application_setting_enum('email_confirmation_setting', 'hard')
        end

        it 'updates the unconfirmed email instead of the email', :aggregate_failures do
          expect(result.payload[:user].unconfirmed_email).to eq(params[:email])
          expect(result.payload[:user].email).not_to eq(params[:email])
        end

        context 'when the group owns the email domain', :saas do
          before do
            stub_licensed_features(service_accounts: true, domain_verification: true)
            project = create(:project, group: group)
            create(:pages_domain, project: project, domain: 'test.com')
          end

          let(:params) { super().merge(email: 'test@test.com') }

          it 'updates the email', :aggregate_failures do
            expect(result.payload[:user].email).to eq(params[:email])
            expect(result.payload[:user].unconfirmed_email).to be_nil
          end
        end
      end
    end

    context 'when current user is not a group owner' do
      let(:current_user) { maintainer }

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
