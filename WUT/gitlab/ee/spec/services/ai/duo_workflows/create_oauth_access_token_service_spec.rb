# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::DuoWorkflows::CreateOauthAccessTokenService, feature_category: :duo_workflow do
  describe '#execute' do
    let_it_be(:organization) { create(:organization) }
    let_it_be(:user) { create(:user, organizations: [organization]) }

    subject(:execute) do
      described_class.new(current_user: user, organization: organization).execute
    end

    before do
      stub_saas_features(duo_workflow: true)
    end

    context 'when the duo workflow oauth application already exists' do
      let_it_be(:oauth_application) do
        create(
          :oauth_application,
          owner: nil,
          id: application_settings.duo_workflow_oauth_application_id,
          scopes: :ai_workflows
        )
      end

      before do
        stub_application_setting({ duo_workflow_oauth_application_id: oauth_application.id })
      end

      context 'when the user does not have a valid oauth access token' do
        shared_examples 'creates a new oauth access token for the duo workflow oauth app' do
          it 'creates a new oauth access token for the duo workflow oauth app' do
            expect { execute }.to change { OauthAccessToken.count }.by(1)
            token = execute[:oauth_access_token]
            expect(token.resource_owner_id).to eq user.id
            expect(token.application).to eq oauth_application
          end
        end

        context 'when oauth token has expired' do
          before do
            create_expired_token
          end

          it_behaves_like 'creates a new oauth access token for the duo workflow oauth app'
        end

        context 'when oauth token is not present' do
          it_behaves_like 'creates a new oauth access token for the duo workflow oauth app'
        end
      end

      context 'when the user already has an oauth access token' do
        it 'creates a new oauth access token' do
          described_class.new(current_user: user, organization: organization).execute

          expect { execute }.to change { OauthAccessToken.count }.by(1)
        end
      end

      context 'when the user does not have the duo_workflow feature flag enabled' do
        it 'returns an error' do
          stub_feature_flags(duo_workflow: false)
          stub_feature_flags(duo_agentic_chat: false)

          expect(execute).to be_error
        end
      end
    end

    context 'when workflow_definition exists' do
      subject(:execute) do
        described_class.new(current_user: user, organization: organization, workflow_definition: workflow_definition)
          .execute
      end

      context 'when workflow_definition is chat' do
        let(:workflow_definition) { 'chat' }

        it 'returns error when duo_agentic_chat feature flag is disabled' do
          stub_feature_flags(duo_agentic_chat: false)

          expect(execute).to be_error
        end

        it 'creates token when duo_agentic_chat feature flag is enabled' do
          expect { execute }.to change { OauthAccessToken.count }.by(1)
        end
      end

      context 'when workflow_definition is software_developer' do
        let(:workflow_definition) { 'software_developer' }

        it 'returns error when duo_workflow feature flag is disabled' do
          stub_feature_flags(duo_workflow: false)

          expect(execute).to be_error
        end

        it 'creates token when duo_workflow feature flag is enabled' do
          stub_feature_flags(duo_workflow: true)

          expect { execute }.to change { OauthAccessToken.count }.by(1)
        end
      end
    end

    context 'when the duo workflow oauth application does not already exists' do
      it 'creates a new doorkeeper oauth application' do
        expect(::Gitlab::CurrentSettings).to receive(:expire_current_application_settings).and_call_original
        expect { execute }.to change { Doorkeeper::Application.count }.by(1)
        expect(application_settings.duo_workflow_oauth_application_id).to eq(Doorkeeper::Application.last&.id)
      end
    end

    def application_settings
      ::Gitlab::CurrentSettings.current_application_settings
    end

    def create_expired_token
      OauthAccessToken.create!(
        application_id: oauth_application.id,
        expires_in: -2.seconds,
        resource_owner_id: user.id,
        token: Doorkeeper::OAuth::Helpers::UniqueToken.generate,
        organization: organization,
        scopes: oauth_application.scopes.to_s
      )
    end
  end
end
