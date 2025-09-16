# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::SecurityComplianceCenterHelper, feature_category: :security_policy_management do
  let_it_be(:user) { build_stubbed(:user) }
  let_it_be(:group) { build_stubbed(:group, :public) }
  let_it_be(:project) { build_stubbed(:project, group: group) }
  let_it_be(:base_data) do
    {
      root_ancestor_path: group.root_ancestor.full_path,
      root_ancestor_name: group.root_ancestor.name,
      group_path: group.full_path,
      active_compliance_frameworks: "false",
      feature_projects_report_enabled: "true",
      can_admin_compliance_frameworks: "true",
      can_access_root_ancestor_compliance_center: "true",
      adherence_v2_enabled: "true",
      policy_display_limit: 10
    }
  end

  describe '#compliance_center_app_data' do
    shared_examples 'includes compliance center app data' do
      it 'includes base data' do
        is_expected.to include(base_data)
      end

      it 'includes base path' do
        is_expected.to include(base_path: base_path)
      end
    end

    context 'for project' do
      let(:base_path) { project_security_compliance_dashboard_path(project) }

      before_all do
        project.add_owner(user)
      end

      before do
        allow(helper).to receive(:current_user) { user }
        allow(helper).to receive(:can?).with(user, :read_compliance_adherence_report, project).and_return(true)
        allow(helper).to receive(:can?).with(user, :read_compliance_violations_report, project).and_return(true)
        allow(helper).to receive(:can?).with(user, :admin_compliance_framework, project).and_return(true)
        allow(helper).to receive(:can?).with(user, :read_compliance_dashboard, project.root_ancestor).and_return(true)
      end

      subject { helper.compliance_center_app_data(project) }

      it 'includes project path' do
        is_expected.to include(project_path: project.full_path)
      end

      it 'includes project id' do
        is_expected.to include(project_id: project.id)
      end

      it_behaves_like 'includes compliance center app data'
    end

    context 'for group' do
      let(:base_path) { group_security_compliance_dashboard_path(group) }

      before_all do
        group.add_owner(user)
      end

      before do
        allow(helper).to receive(:current_user) { user }

        allow(helper).to receive(:can?).with(user, :read_compliance_adherence_report, group).and_return(true)
        allow(helper).to receive(:can?).with(user, :read_compliance_violations_report, group).and_return(true)
        allow(helper).to receive(:can?).with(user, :read_security_orchestration_policies, group).and_return(true)
        allow(helper).to receive(:can?).with(user, :admin_compliance_pipeline_configuration, group).and_return(true)
        allow(helper).to receive(:can?).with(user, :admin_compliance_framework, group).and_return(true)
        allow(helper).to receive(:can?).with(user, :read_compliance_dashboard, group).and_return(true)
        allow(helper).to receive(:can_modify_security_policy?).with(group).and_return(true)
      end

      subject { helper.compliance_center_app_data(group) }

      it 'includes group path' do
        is_expected.to include(group_path: group.full_path)
      end

      it 'includes export paths' do
        compliance_status_report_export_path =
          group_security_compliance_dashboard_exports_compliance_status_report_path(group, format: :csv)

        is_expected.to include(
          violations_csv_export_path: group_security_compliance_violation_reports_path(group, format: :csv),
          project_frameworks_csv_export_path: group_security_compliance_project_framework_reports_path(group,
            format: :csv),
          adherences_csv_export_path: group_security_compliance_standards_adherence_reports_path(group, format: :csv),
          frameworks_csv_export_path: group_security_compliance_framework_reports_path(group, format: :csv),
          merge_commits_csv_export_path: group_security_merge_commit_reports_path(group),
          compliance_status_report_export_path: compliance_status_report_export_path
        )
      end

      it_behaves_like 'includes compliance center app data'

      context 'with enable_standards_adherence_dashboard_v2 off' do
        before do
          stub_feature_flags(enable_standards_adherence_dashboard_v2: false)
        end

        it 'returns the expected value for attribues based on ff' do
          is_expected.to include(
            compliance_status_report_export_path: nil,
            adherence_v2_enabled: "false"
          )
        end
      end
    end
  end
end
