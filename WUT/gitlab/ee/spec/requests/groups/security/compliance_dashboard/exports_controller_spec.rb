# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::Security::ComplianceDashboard::ExportsController, feature_category: :compliance_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }

  describe 'GET #compliance_status_report' do
    let(:export_service) do
      instance_double(ComplianceManagement::ComplianceFramework::ProjectRequirementStatuses::ExportService)
    end

    subject(:compliance_status_report_request) do
      get group_security_compliance_dashboard_exports_compliance_status_report_path(group, format: :csv)
    end

    before do
      sign_in(user)
      stub_licensed_features(group_level_compliance_dashboard: true)
    end

    context 'when user is not authorized' do
      before_all do
        group.add_maintainer(user)
      end

      it 'returns 404' do
        compliance_status_report_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user is authorized' do
      before_all do
        group.add_owner(user)
      end

      before do
        allow(ComplianceManagement::ComplianceFramework::ProjectRequirementStatuses::ExportService)
          .to receive(:new)
          .with(user: user, group: group)
          .and_return(export_service)

        allow(export_service).to receive(:email_export)
      end

      it 'initiates the export service' do
        compliance_status_report_request

        expect(export_service).to have_received(:email_export)
      end

      it 'sets a flash notice' do
        compliance_status_report_request

        expect(flash[:notice]).to eq('After the report is generated, an email will be sent with the report attached.')
      end

      it 'redirects to the compliance dashboard' do
        compliance_status_report_request

        expect(response).to redirect_to(group_security_compliance_dashboard_path(group))
      end
    end
  end
end
