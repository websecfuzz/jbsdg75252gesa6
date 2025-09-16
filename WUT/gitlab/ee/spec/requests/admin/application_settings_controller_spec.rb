# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::ApplicationSettingsController, :enable_admin_mode, feature_category: :shared do
  include StubENV

  let(:admin) { create(:admin) }

  before do
    sign_in(admin)
    stub_env('IN_MEMORY_APPLICATION_SETTINGS', 'false')
  end

  describe 'PUT update_microsoft_application', feature_category: :system_access do
    let(:params) do
      { system_access_microsoft_application: attributes_for(:system_access_microsoft_application) }
    end

    let(:path) { update_microsoft_application_admin_application_settings_path }

    subject(:update_request) { put path, params: params }

    before do
      allow(::Gitlab::Auth::Saml::Config).to receive(:microsoft_group_sync_enabled?).and_return(true)
    end

    it 'raises an error when parameters are missing' do
      expect { put path }.to raise_error(ActionController::ParameterMissing)
    end

    it 'redirects with error alert when missing required attributes' do
      put path, params: { system_access_microsoft_application: { enabled: true } }

      expect(response).to have_gitlab_http_status(:redirect)
      expect(flash[:alert]).to include('Microsoft Azure integration settings failed to save.')
    end

    it 'redirects with success notice' do
      put path, params: params

      expect(response).to have_gitlab_http_status(:redirect)
      expect(flash[:notice]).to eq(s_('Microsoft|Microsoft Azure integration settings were successfully updated.'))
    end

    it 'creates new SystemAccess::MicrosoftApplication' do
      expect { update_request }.to change { SystemAccess::MicrosoftApplication.count }.by(1)
    end

    it 'does not create a SystemAccess::GroupMicrosoftApplication' do
      expect { update_request }.not_to change { SystemAccess::GroupMicrosoftApplication.count }
    end
  end

  describe 'GET #general', feature_category: :user_management do
    context 'when microsoft_group_sync_enabled? is true' do
      before do
        allow(::Gitlab::Auth::Saml::Config).to receive(:microsoft_group_sync_enabled?).and_return(true)
      end

      it 'initializes correctly with SystemAccess::MicrosoftApplication' do
        create(:system_access_microsoft_application, namespace: nil, client_xid: 'test-xid-456')

        get general_admin_application_settings_path

        expect(response.body).to match(/test-xid-456/)
      end
    end

    it 'does push :disable_private_profiles license feature' do
      expect_next_instance_of(described_class) do |instance|
        expect(instance).to receive(:push_licensed_feature).with(:password_complexity)
        expect(instance).to receive(:push_licensed_feature).with(:seat_control)
        expect(instance).to receive(:push_licensed_feature).with(:disable_private_profiles)
      end

      get general_admin_application_settings_path
    end
  end
end
