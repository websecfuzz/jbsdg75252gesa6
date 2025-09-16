# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::OnboardingService, type: :service, feature_category: :duo_workflow do
  describe '#execute', :enable_admin_mode do
    let_it_be(:organization) { create(:organization) }
    let_it_be(:user) { create(:admin, organizations: [organization]) }
    let_it_be(:doorkeeper_application) { create(:doorkeeper_application) }

    before do
      allow(License).to receive(:current).and_return(create(:license, plan: License::ULTIMATE_PLAN))
      stub_licensed_features(service_accounts: true)
    end

    subject(:instance) { described_class.new(current_user: user, organization: organization) }

    context 'when duo workflow service account does not already exist' do
      it 'creates service account with composite identity stores the user id in ai settings' do
        expect(Ai::Setting.instance.duo_workflow_service_account_user_id).to be_falsey

        instance.execute

        service_account_user_id = Ai::Setting.instance.duo_workflow_service_account_user_id
        expect(service_account_user_id).to be_truthy

        service_account_user = User.find_by_id(service_account_user_id)
        expect(service_account_user.composite_identity_enforced?).to be true
        expect(service_account_user.private_profile?).to be true
      end
    end

    context 'when duo workflow service account already exists' do
      let_it_be(:service_account) { create(:service_account) }

      before do
        Ai::Setting.instance.update!(duo_workflow_service_account_user_id: service_account.id)
        allow(::Users::ServiceAccounts::CreateService).to receive(:new)
      end

      it 'does not attempt to create a service account' do
        expect { instance.execute }.not_to change { Ai::Setting.instance.duo_workflow_service_account_user_id }
        expect(::Users::ServiceAccounts::CreateService).not_to have_received(:new)
      end
    end

    context 'when an existing oauth application does not exist' do
      it 'creates a new oauth application' do
        expect(Ai::Setting.instance.duo_workflow_oauth_application_id).to be_nil

        expect(Doorkeeper::Application).to receive(:new).with(
          {
            name: 'GitLab Duo Workflow Composite OAuth Application',
            redirect_uri: Gitlab::Routing.url_helpers.root_url,
            scopes: [:ai_workflows, :"user:*"],
            trusted: true,
            confidential: true
          }
        ).and_return(doorkeeper_application)

        instance.execute

        expect(Ai::Setting.instance.duo_workflow_oauth_application_id).to eq(doorkeeper_application.id)
      end
    end

    context 'when an oauth application exists' do
      before do
        Ai::Setting.instance.update!(duo_workflow_oauth_application_id: doorkeeper_application.id)
      end

      it 'does not create a new oauth application' do
        expect { instance.execute }.not_to change {
          Ai::Setting.instance.duo_workflow_oauth_application_id
        }
        expect(Doorkeeper::Application).not_to receive(:new)
      end
    end

    context 'when service account create service fails' do
      before do
        stub_licensed_features(service_accounts: false)
      end

      it 'returns the error from the service' do
        response = instance.execute

        expect(response).to be_error
        expect(response.message).to eq('User does not have permission to create a service account.')
      end
    end
  end
end
