# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::EE::Gitlab::Scim::ProvisioningService, feature_category: :system_access do
  include LoginHelpers

  describe '#execute' do
    let_it_be(:organization) { create(:organization) }

    let(:service) { described_class.new(service_params) }
    let_it_be(:service_params) do
      {
        email: 'work@example.com',
        name: 'Test Name',
        extern_uid: 'test_uid',
        username: 'username',
        organization_id: organization.id
      }
    end

    shared_examples 'success response' do
      it 'contains a success status' do
        expect(service.execute.status).to eq(:success)
      end

      it 'contains an identity in the response' do
        expect(service.execute.identity).to be_a(Identity).or be_a(ScimIdentity)
      end
    end

    it 'creates the SCIM identity' do
      expect { service.execute }.to change { ScimIdentity.count }.by(1)
    end

    it 'does not creates the SAML identity' do
      expect { service.execute }.not_to change { Identity.count }
    end

    context 'when valid params' do
      let_it_be(:service_params) do
        {
          email: 'work@example.com',
          name: 'Test Name',
          extern_uid: 'test_uid',
          username: 'username',
          organization_id: organization.id
        }
      end

      def user
        User.find_by(email: service_params[:email])
      end

      it_behaves_like 'success response'

      it 'creates the user' do
        expect { service.execute }.to change { User.count }.by(1)
      end

      it 'creates the correct user attributes' do
        service.execute

        expect(user).to be_a(User)
      end

      context 'when email confirmation setting is set' do
        using RSpec::Parameterized::TableSyntax

        where(:email_confirmation_setting, :confirmed) do
          'soft' | false
          'hard' | false
          'off' | true
        end

        with_them do
          before do
            stub_application_setting_enum('email_confirmation_setting', email_confirmation_setting)
          end

          it "sets user confirmation according to setting" do
            service.execute

            expect(user).to be_present
            expect(user.reload.confirmed?).to be(confirmed)
          end
        end
      end

      context 'when the current minimum password length is different from the default minimum password length' do
        before do
          stub_application_setting minimum_password_length: 21
        end

        it 'creates the user' do
          expect { service.execute }.to change { User.count }.by(1)
        end
      end

      context 'when username contains invalid characters' do
        subject(:result) { service.execute }

        let_it_be(:service_params) do
          {
            email: 'work@example.com',
            name: 'Test Name',
            extern_uid: 'test_uid',
            username: ' --ricky.^#!__the._raccoon--',
            organization_id: organization.id
          }
        end

        it 'sanitizes more special characters from the username' do
          expect { result }.to change { User.count }.by(1)
          expect(user.username).to eq('ricky.the.raccoon')
        end

        context 'and there is an existing user with the sanitized username' do
          before do
            create(:user, :with_namespace, username: 'ricky.the.raccoon')
          end

          it 'creates new user with non-conflicting username' do
            expect { result }.to change { User.count }.by(1)
            expect(user.username).to eq('ricky.the.raccoon1')
          end
        end
      end
    end

    context 'when invalid params' do
      let_it_be(:service_params) do
        {
          email: 'work@example.com',
          name: 'Test Name',
          extern_uid: 'test_uid',
          organization_id: organization.id
        }
      end

      it 'fails with error' do
        expect(service.execute.status).to eq(:error)
      end

      it 'fails with missing params' do
        expect(service.execute.message).to eq("Missing params: [:username]")
      end

      context 'when invalid user params' do
        let_it_be(:service_params) do
          {
            email: 'work@example.com',
            name: 'Test Name',
            extern_uid: '',
            username: '',
            organization_id: organization.id
          }
        end

        let(:provision_response) do
          ::EE::Gitlab::Scim::ProvisioningResponse.new(identity: nil,
            status: :error,
            message: "Extern uid can't be blank")
        end

        it 'does not return nil result' do
          expect(service.execute).not_to be_nil
        end

        it 'returns error response' do
          expect(service.execute.to_json).to eq(provision_response.to_json)
        end
      end
    end

    context 'for an existing user' do
      before do
        create(:email, :confirmed, user: user, email: 'work@example.com')
      end

      let(:user) { create(:user) }

      it 'does not create a new user' do
        expect { service.execute }.not_to change { User.count }
      end

      it_behaves_like 'success response'

      it 'creates the SCIM identity' do
        expect { service.execute }.to change { ScimIdentity.count }.by(1)
      end

      it 'does not create the SAML identity' do
        expect { service.execute }.not_to change { Identity.count }
      end

      context 'when invalid identity' do
        let_it_be(:service_params) do
          {
            email: 'work@example.com',
            name: 'Test Name',
            extern_uid: '',
            username: 'username',
            organization_id: organization.id
          }
        end

        let(:provision_response) do
          ::EE::Gitlab::Scim::ProvisioningResponse.new(identity: nil,
            status: :error,
            message: "Extern uid can't be blank")
        end

        it 'does not return nil result' do
          expect(service.execute).not_to be_nil
        end

        it 'returns error response' do
          expect(service.execute.to_json).to eq(provision_response.to_json)
        end
      end
    end
  end
end
