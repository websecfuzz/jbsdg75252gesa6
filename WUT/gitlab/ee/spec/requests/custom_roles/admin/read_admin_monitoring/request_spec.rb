# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User with read_admin_monitoring', :enable_admin_mode, feature_category: :audit_events do
  let_it_be(:current_user) { create(:user) }
  let_it_be(:permission) { :read_admin_monitoring }
  let_it_be(:role) { create(:admin_member_role, permission, user: current_user) }

  before do
    stub_licensed_features(admin_audit_log: true, custom_roles: true)
    sign_in(current_user)
  end

  describe Admin::AuditLogsController do
    it "GET #index" do
      get admin_audit_logs_path

      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to render_template(:index)
    end
  end

  describe Admin::AuditLogReportsController do
    it "GET #index" do
      get admin_audit_log_reports_path(format: :csv)

      expect(response).to have_gitlab_http_status(:ok)
    end
  end

  describe Admin::BackgroundMigrationsController do
    it "GET #index" do
      get admin_background_migrations_path

      expect(response).to have_gitlab_http_status(:ok)
    end

    it "GET #show" do
      migration = create(:batched_background_migration_job)
      get admin_background_migration_path(migration)

      expect(response).to have_gitlab_http_status(:ok)
    end
  end

  describe Admin::GitalyServersController do
    it "GET #index" do
      get admin_gitaly_servers_path

      expect(response).to have_gitlab_http_status(:ok)
    end
  end

  describe Admin::HealthCheckController do
    it "GET #show" do
      get admin_health_check_path

      expect(response).to have_gitlab_http_status(:ok)
    end
  end

  describe Admin::SystemInfoController do
    it "GET #show" do
      get admin_system_info_path

      expect(response).to have_gitlab_http_status(:ok)
    end
  end

  describe Admin::DashboardController do
    describe "#index" do
      it 'user has access via a custom role' do
        get admin_root_path

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to render_template(:index)
      end
    end
  end
end
