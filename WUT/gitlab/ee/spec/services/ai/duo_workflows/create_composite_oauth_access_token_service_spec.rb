# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::DuoWorkflows::CreateCompositeOauthAccessTokenService, feature_category: :duo_workflow do
  describe '#execute' do
    let_it_be(:organization) { create(:organization) }
    let_it_be_with_reload(:service_account) { create(:user, :service_account, composite_identity_enforced: true) }
    let_it_be(:user) { create(:user, organizations: [organization]) }
    let_it_be(:oauth_app) { create(:doorkeeper_application) }

    subject(:response) do
      described_class.new(current_user: user, organization: organization).execute
    end

    before do
      stub_saas_features(duo_workflow: true)
    end

    context 'when the duo workflow onboarding is complete' do
      before do
        ::Ai::Setting.instance.update!(
          duo_workflow_service_account_user_id: service_account.id,
          duo_workflow_oauth_application_id: oauth_app.id
        )
      end

      it 'creates a new oauth access token' do
        expect { response }.to change { OauthAccessToken.count }.by(1)
        expect(response).to be_success
      end

      context 'when service account does not have composite identity enabled' do
        before do
          service_account.update!(composite_identity_enforced: false)
        end

        it 'raises CompositeIdentityEnforcedError' do
          expect { response }.to raise_error(
            ::Ai::DuoWorkflows::CreateCompositeOauthAccessTokenService::CompositeIdentityEnforcedError,
            "The Duo Workflow service account must have composite identity enabled."
          )
        end
      end

      context 'when the user does not have the duo_workflow feature flag enabled' do
        before do
          stub_feature_flags(duo_workflow_in_ci: false)
        end

        it 'returns an error' do
          expect(response).to be_error
          expect(response.message).to eq('Can not generate token to execute workflow in CI')
        end
      end
    end

    context 'when the duo workflow onboarding is not complete' do
      it 'raises exception' do
        expect { response }.to raise_error(
          ::Ai::DuoWorkflows::CreateCompositeOauthAccessTokenService::IncompleteOnboardingError,
          'Duo Workflow onboarding is incomplete. Please complete onboarding to proceed further.'
        )
      end
    end
  end
end
