# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::Security::SastConfigurationController,
  feature_category: :static_application_security_testing do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :repository, namespace: group) }
  let_it_be(:developer) { create(:user, developer_of: group) }
  let_it_be(:guest) { create(:user, guest_of: group) }

  before do
    stub_licensed_features(security_dashboard: true)
  end

  describe 'GET #show' do
    subject(:request) { get :show, params: { namespace_id: project.namespace, project_id: project } }

    render_views

    include_context '"Security and compliance" permissions' do
      let(:valid_request) { request }

      before_request do
        sign_in(developer)
      end
    end

    it_behaves_like SecurityDashboardsPermissions do
      let(:vulnerable) { project }
      let(:security_dashboard_action) { request }
    end

    context 'with authorized user' do
      before do
        sign_in(developer)
      end

      it 'renders the show template' do
        request

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to render_template(:show)
      end
    end

    context 'with unauthorized user' do
      before do
        sign_in(guest)
      end

      it 'returns a 403' do
        request

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end
end
