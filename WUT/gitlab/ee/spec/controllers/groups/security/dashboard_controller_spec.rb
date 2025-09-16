# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::Security::DashboardController, feature_category: :vulnerability_management do
  let(:user) { create(:user) }
  let(:group) { create(:group) }

  before do
    sign_in(user)
  end

  describe 'GET show' do
    subject(:show_security_dashboard) { get :show, params: { group_id: group.to_param } }

    context 'when security dashboard feature is enabled' do
      before do
        stub_licensed_features(security_dashboard: true)
      end

      context 'and user is allowed to access group security dashboard' do
        before do
          group.add_developer(user)
        end

        it { is_expected.to have_gitlab_http_status(:ok) }
        it { is_expected.to render_template(:show) }

        it_behaves_like 'tracks govern usage event', 'security_dashboard' do
          let(:request) { subject }
        end

        it_behaves_like 'internal event tracking' do
          let(:event) { 'visit_security_dashboard' }
          let(:namespace) { group }
          let(:category) { described_class.name }
          subject(:service_action) { show_security_dashboard }
        end
      end

      context 'when user is not allowed to access group security dashboard' do
        it { is_expected.to have_gitlab_http_status(:ok) }
        it { is_expected.to render_template(:unavailable) }

        it_behaves_like "doesn't track govern usage event", 'security_dashboard' do
          let(:request) { subject }
        end

        it 'does not record events or metrics' do
          expect { show_security_dashboard }.not_to trigger_internal_events('visit_security_dashboard')
        end
      end
    end

    context 'when security dashboard feature is disabled' do
      it { is_expected.to have_gitlab_http_status(:ok) }
      it { is_expected.to render_template(:unavailable) }

      it_behaves_like "doesn't track govern usage event", 'security_dashboard' do
        let(:request) { subject }
      end

      it 'does not record events or metrics' do
        expect { show_security_dashboard }.not_to trigger_internal_events('visit_security_dashboard')
      end
    end
  end
end
