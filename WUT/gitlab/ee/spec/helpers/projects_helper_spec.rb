# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProjectsHelper, feature_category: :shared do
  include ::EE::GeoHelpers
  using RSpec::Parameterized::TableSyntax

  let_it_be_with_refind(:project) { create(:project) }

  before do
    helper.instance_variable_set(:@project, project)
  end

  describe 'default_clone_protocol' do
    context 'when gitlab.config.kerberos is enabled and user is logged in' do
      it 'returns krb5 as default protocol' do
        allow(Gitlab.config.kerberos).to receive(:enabled).and_return(true)
        allow(helper).to receive(:current_user).and_return(double)

        expect(helper.send(:default_clone_protocol)).to eq('krb5')
      end
    end
  end

  describe '#show_no_ssh_key_message?' do
    let_it_be(:group) do
      created_group = create(:group)
      created_group.enforce_ssh_certificates = true
      created_group.save!

      created_group
    end

    let_it_be(:project) { create(:project, group: group) }

    context 'when ssh certificates are enforced' do
      it 'returns false' do
        expect(helper.show_no_ssh_key_message?(project)).to be_falsey
      end
    end
  end

  describe '#show_compliance_frameworks_info?' do
    context 'when feature is licensed' do
      before do
        stub_licensed_features(custom_compliance_frameworks: true)
      end

      it 'returns false if compliance framework setting is not present' do
        expect(helper.show_compliance_frameworks_info?(project)).to be_falsey
      end

      it 'returns true if compliance framework setting is present' do
        project = build(:project, :with_compliance_framework)

        expect(helper.show_compliance_frameworks_info?(project)).to be_truthy
      end
    end

    context 'when feature is unlicensed' do
      before do
        stub_licensed_features(custom_compliance_frameworks: false)
      end

      it 'returns false if compliance framework setting is not present' do
        expect(helper.show_compliance_frameworks_info?(project)).to be_falsey
      end

      it 'returns false if compliance framework setting is present' do
        project = build_stubbed(:project, :with_compliance_framework)

        expect(helper.show_compliance_frameworks_info?(project)).to be_falsey
      end
    end
  end

  describe '#compliance_center_path' do
    it 'returns the path to the project security compliance dashboard' do
      expect(helper.compliance_center_path(project))
        .to eq(project_security_compliance_dashboard_path(project, vueroute: "frameworks"))
    end
  end

  describe '#membership_locked?' do
    let(:project) { build_stubbed(:project, group: group) }
    let(:group) { nil }

    context 'when project has no group' do
      let(:project) { Project.new }

      it 'is false' do
        expect(helper).not_to be_membership_locked
      end
    end

    context 'with group_membership_lock enabled' do
      let(:group) { build_stubbed(:group, membership_lock: true) }

      it 'is true' do
        expect(helper).to be_membership_locked
      end
    end

    context 'with global LDAP membership lock enabled' do
      before do
        stub_application_setting(lock_memberships_to_ldap: true)
      end

      context 'and group membership_lock disabled' do
        let(:group) { build_stubbed(:group, membership_lock: false) }

        it 'is true' do
          expect(helper).to be_membership_locked
        end
      end
    end

    context 'with SAML membership lock enabled and group membership_lock disabled' do
      before do
        stub_application_setting(lock_memberships_to_saml: true)
      end

      let(:group) { build_stubbed(:group, membership_lock: false) }

      it 'is true' do
        expect(helper).to be_membership_locked
      end
    end
  end

  describe '#group_project_templates_count' do
    let_it_be(:user) { create(:user) }
    let_it_be(:parent_group) { create(:group, name: 'parent-group') }
    let_it_be(:template_group) { create(:group, parent: parent_group, name: 'template-group') }
    let_it_be_with_reload(:template_project) { create(:project, group: template_group, name: 'template-project') }

    before_all do
      parent_group.update!(custom_project_templates_group_id: template_group.id)
      parent_group.add_owner(user)
    end

    before do
      allow(helper).to receive_messages(current_user: user, can?: true)
    end

    specify do
      expect(helper.group_project_templates_count(parent_group.id)).to eq 1
    end

    it 'preloads the policy requirements' do
      expect(::Preloaders::ProjectPolicyPreloader)
        .to receive(:new).with(kind_of(ActiveRecord::Relation), user).and_call_original
      expect(::Namespaces::Preloaders::ProjectRootAncestorPreloader).to receive(:new).at_least(:once).and_call_original

      helper.group_project_templates_count(parent_group.id)
    end

    context 'when template project is pending deletion' do
      before do
        template_project.update!(marked_for_deletion_at: Date.current)
      end

      specify do
        expect(helper.group_project_templates_count(parent_group.id)).to eq 0
      end
    end

    context 'when template project is archived' do
      before do
        template_project.update!(archived: true)
      end

      it 'does not return the project' do
        expect(helper.group_project_templates_count(parent_group.id)).to eq 0
        expect(helper.group_project_templates_count(template_group.id)).to eq 0
      end

      context 'when "project_templates_without_min_access" FF is disabled' do
        before do
          stub_feature_flags(project_templates_without_min_access: false)
        end

        it 'does not return the project' do
          expect(helper.group_project_templates_count(parent_group.id)).to eq 0
          expect(helper.group_project_templates_count(template_group.id)).to eq 0
        end
      end
    end

    context 'when project is not visible to user' do
      before do
        allow(helper).to receive(:can?).with(user, :download_code, template_project).and_return(false)
      end

      specify do
        expect(helper.group_project_templates_count(parent_group.id)).to eq 0
      end

      context 'when feature flag "project_templates_without_min_access" is disabled' do
        before do
          stub_feature_flags(project_templates_without_min_access: false)
        end

        specify do
          expect(helper.group_project_templates_count(parent_group.id)).to eq 1
        end
      end
    end

    context 'when there are multiple groups' do
      before do
        allow(helper).to receive(:can?).and_call_original
      end

      it 'does not cause a N+1 problem' do
        control = ActiveRecord::QueryRecorder.new { helper.group_project_templates_count(nil) }

        parent_group2 = create(:group, name: 'parent-group2')
        template_group2 = create(:group, parent: parent_group2, name: 'template-group2')
        create(:project, group: template_group2, name: 'template-project2')
        parent_group2.update!(custom_project_templates_group_id: template_group2.id)
        parent_group2.add_owner(user)

        # Namespace parent loads and authorization checks
        threshold = 4

        expect do
          helper.group_project_templates_count(nil)
        end.not_to exceed_query_limit(control).with_threshold(threshold)
      end
    end
  end

  describe '#group_project_templates' do
    let_it_be(:user) { create(:user) }
    let_it_be(:parent_group) { create(:group, name: 'parent-group') }
    let_it_be(:template_group) { create(:group, parent: parent_group, name: 'template-group') }
    let_it_be_with_reload(:template_project) { create(:project, group: template_group, name: 'template-project') }

    before_all do
      parent_group.update!(custom_project_templates_group_id: template_group.id)
      parent_group.add_owner(user)
    end

    before do
      allow(helper).to receive_messages(current_user: user, can?: true)
    end

    specify do
      expect(helper.group_project_templates(parent_group)).to match_array([template_project])
    end

    context 'when template project is pending deletion' do
      before do
        template_project.update!(marked_for_deletion_at: Date.current)
      end

      specify do
        expect(helper.group_project_templates(parent_group)).to be_empty
      end
    end

    context 'when template project is archived' do
      before do
        template_project.update!(archived: true)
      end

      it 'does not return the project' do
        expect(helper.group_project_templates(parent_group)).to be_empty
        expect(helper.group_project_templates(template_group)).to be_empty
      end

      context 'when "project_templates_without_min_access" FF is disabled' do
        before do
          stub_feature_flags(project_templates_without_min_access: false)
        end

        it 'does not return the project' do
          expect(helper.group_project_templates(parent_group)).to be_empty
          expect(helper.group_project_templates(template_group)).to be_empty
        end
      end
    end

    context 'when project is not visible to user' do
      before do
        allow(helper).to receive(:can?).and_return(false)
      end

      specify do
        expect(helper.group_project_templates(parent_group)).to be_empty
      end

      context 'when feature flag "project_templates_without_min_access" is disabled' do
        before do
          stub_feature_flags(project_templates_without_min_access: false)
        end

        specify do
          expect(helper.group_project_templates(parent_group)).to be_empty
        end
      end
    end
  end

  describe '#project_security_dashboard_config' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, :repository, group: group) }
    let_it_be(:jira_integration) do
      create(:jira_integration, project: project, vulnerabilities_enabled: true,
        project_key: 'GV', vulnerabilities_issuetype: '10000')
    end

    let_it_be(:dismissal_descriptions_json) do
      Gitlab::Json.parse(fixture_file('vulnerabilities/dismissal_descriptions.json', dir: 'ee')).to_json
    end

    subject { helper.project_security_dashboard_config(project) }

    before_all do
      group.add_owner(user)
    end

    before do
      stub_licensed_features(jira_vulnerabilities_integration: true)
      allow(helper).to receive_messages(current_user: user, can?: true)
    end

    context 'for project with third party offers hidden' do
      before do
        allow(::Gitlab::CurrentSettings.current_application_settings)
          .to receive(:hide_third_party_offers?).and_return(true)
      end

      it { is_expected.to include(hide_third_party_offers: 'true') }
    end

    context 'for project without vulnerabilities' do
      let(:expected_value) do
        {
          has_vulnerabilities: 'false',
          has_jira_vulnerabilities_integration_enabled: 'true',
          empty_state_svg_path: start_with('/assets/illustrations/empty-state/empty-secure-md'),
          operational_configuration_path: new_project_security_policy_path(project),
          security_dashboard_empty_svg_path: start_with('/assets/illustrations/empty-state/empty-secure-md'),
          project: { id: project.id, name: project.name },
          project_full_path: project.full_path,
          no_vulnerabilities_svg_path: start_with('/assets/illustrations/empty-state/empty-search-md-'),
          security_configuration_path: end_with('/configuration'),
          can_admin_vulnerability: 'true',
          new_vulnerability_path: end_with('/security/vulnerabilities/new'),
          dismissal_descriptions: dismissal_descriptions_json,
          hide_third_party_offers: 'false',
          show_retention_alert: 'false'
        }
      end

      it { is_expected.to match(expected_value) }
    end

    context 'for project with vulnerabilities' do
      let_it_be(:vulnerability) { create(:vulnerability, project: project) }
      let(:scanner) { vulnerability.vulnerability_finding.scanner }

      let(:base_values) do
        vulnerabilities_export = "/api/v4/security/projects/#{project.id}/vulnerability_exports"

        {
          has_vulnerabilities: 'true',
          has_jira_vulnerabilities_integration_enabled: 'true',
          project: { id: project.id, name: project.name },
          project_full_path: project.full_path,
          vulnerabilities_export_endpoint: vulnerabilities_export,
          vulnerabilities_pdf_export_endpoint: "#{vulnerabilities_export}?export_format=pdf",
          no_vulnerabilities_svg_path: start_with('/assets/illustrations/empty-state/empty-search-md-'),
          empty_state_svg_path: start_with('/assets/illustrations/empty-state/empty-secure-md'),
          operational_configuration_path: new_project_security_policy_path(project),
          security_dashboard_empty_svg_path: start_with('/assets/illustrations/empty-state/empty-secure-md'),
          new_project_pipeline_path: "/#{project.full_path}/-/pipelines/new",
          scanners: [{
            id: scanner.id,
            vendor: scanner.vendor,
            report_type: vulnerability.report_type.upcase,
            name: scanner.name,
            external_id: scanner.external_id
          }].to_json,
          can_admin_vulnerability: 'true',
          can_view_false_positive: 'false',
          security_configuration_path: kind_of(String),
          new_vulnerability_path: end_with('/security/vulnerabilities/new'),
          dismissal_descriptions: dismissal_descriptions_json,
          hide_third_party_offers: 'false',
          show_retention_alert: 'false',
          vulnerability_quota: {
            critical: 'true',
            exceeded: 'false',
            full: 'false'
          }
        }
      end

      before do
        allow(project.vulnerability_quota).to receive(:critical?).and_return(true)
      end

      context 'with related_url_root set' do
        let(:relative_url) { '/gitlab' }
        let(:expected_path) { "#{relative_url}/api/v4/security/projects/#{project.id}/vulnerability_exports" }
        let(:expected_value) do
          base_values.merge(
            vulnerabilities_export_endpoint: expected_path,
            vulnerabilities_pdf_export_endpoint: "#{expected_path}?export_format=pdf"
          )
        end

        before do
          stub_config_setting(relative_url_root: relative_url)
        end

        it { is_expected.to match(expected_value) }
      end

      context 'without pipeline' do
        before do
          allow(project).to receive(:latest_ingested_security_pipeline).and_return(nil)
        end

        it { is_expected.to match(base_values) }
      end

      context 'with security pipeline' do
        let(:pipeline_created_at) { '1881-05-19T00:00:00Z' }
        let(:pipeline) { build_stubbed(:ci_pipeline, project: project, created_at: pipeline_created_at) }
        let(:pipeline_values) do
          {
            pipeline: {
              id: pipeline.id,
              path: "/#{project.full_path}/-/pipelines/#{pipeline.id}",
              created_at: pipeline_created_at,
              has_warnings: 'true',
              has_errors: 'false',
              security_builds: {
                failed: {
                  count: 0,
                  path: "/#{project.full_path}/-/pipelines/#{pipeline.id}/failures"
                }
              }
            }
          }
        end

        before do
          allow(project)
            .to receive_messages(latest_ingested_security_pipeline: pipeline, latest_ingested_sbom_pipeline: nil)
          allow(pipeline).to receive_messages(
            has_security_report_ingestion_warnings?: true,
            has_security_report_ingestion_errors?: false
          )
        end

        it { is_expected.to match(base_values.merge!(pipeline_values)) }

        context 'with sbom pipeline' do
          let(:sbom_pipeline_created_at) { '1981-07-19T00:00:00Z' }
          let(:sbom_pipeline) { build_stubbed(:ci_pipeline, project: project, created_at: sbom_pipeline_created_at) }
          let(:sbom_pipeline_values) do
            {
              sbom_pipeline: {
                id: sbom_pipeline.id,
                path: "/#{project.full_path}/-/pipelines/#{sbom_pipeline.id}",
                created_at: sbom_pipeline_created_at,
                has_warnings: '',
                has_errors: 'true'
              }
            }
          end

          before do
            allow(project).to receive(:latest_ingested_sbom_pipeline).and_return(sbom_pipeline)
            allow(sbom_pipeline).to receive(:has_sbom_report_ingestion_errors?).and_return(true)
          end

          it { is_expected.to match(base_values.merge(sbom_pipeline_values, pipeline_values)) }
        end
      end
    end
  end

  describe '#show_discover_project_security?' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:user) { create(:user) }

    where(
      gitlab_com?: [true, false],
      user?: [true, false],
      security_dashboard_feature_available?: [true, false],
      can_admin_namespace?: [true, false]
    )

    with_them do
      it 'returns the expected value' do
        allow(::Gitlab).to receive(:com?) { gitlab_com? }
        allow(helper).to receive(:current_user) { user? ? user : nil }
        allow(project).to receive(:feature_available?) { security_dashboard_feature_available? }
        allow(helper).to receive(:can?) { can_admin_namespace? }

        expected_value = user? && gitlab_com? && !security_dashboard_feature_available? && can_admin_namespace?

        expect(helper.show_discover_project_security?(project)).to eq(expected_value)
      end
    end
  end

  describe '#project_permissions_settings' do
    using RSpec::Parameterized::TableSyntax

    before do
      stub_application_setting(spp_repository_pipeline_access: false, lock_spp_repository_pipeline_access: false)
    end

    let(:expected_settings) do
      { requirementsAccessLevel: 20, securityAndComplianceAccessLevel: 10 }
    end

    subject { helper.project_permissions_settings(project) }

    it { is_expected.to include(expected_settings) }

    context 'for cveIdRequestEnabled' do
      where(:project_attrs, :expected) do
        [:public]   | true
        [:internal] | false
        [:private]  | false
      end

      with_them do
        let(:project) { create(:project, :with_cve_request, *project_attrs) }
        subject(:settings) { helper.project_permissions_settings(project) }

        it 'has the correct cveIdRequestEnabled value' do
          expect(settings[:cveIdRequestEnabled]).to eq(expected)
        end
      end
    end

    describe 'sppRepositoryPipelineAccess' do
      it { is_expected.to include(sppRepositoryPipelineAccess: true) }

      context 'when the setting is disabled' do
        before do
          project.project_setting.update!(spp_repository_pipeline_access: false)
        end

        it { is_expected.to include(sppRepositoryPipelineAccess: false) }
      end
    end
  end

  describe '#project_permissions_panel_data' do
    using RSpec::Parameterized::TableSyntax

    let(:user) { instance_double(User, can_admin_all_resources?: false) }
    let(:expected_data) do
      { requirementsAvailable: false, sppRepositoryPipelineAccessLocked: false, policySettingsAvailable: false }
    end

    subject(:data) { helper.project_permissions_panel_data(project) }

    before do
      allow(helper).to receive_messages(current_user: user, can?: false)
    end

    it { is_expected.to include(expected_data) }

    context "if in Gitlab.com" do
      where(is_gitlab_com: [true, false])
      with_them do
        before do
          allow(Gitlab).to receive(:com?).and_return(is_gitlab_com)
        end

        it 'sets requestCveAvailable to the correct value' do
          expect(data[:requestCveAvailable]).to eq(is_gitlab_com)
        end
      end
    end

    describe 'policy settings' do
      describe 'policySettingsAvailable' do
        where(:licensed_feature, :policy_project_exists, :result) do
          true  | true  | true
          true  | false | false
          false | true  | false
          false | false | false
        end

        with_them do
          before do
            stub_licensed_features(security_orchestration_policies: licensed_feature)
            allow(::Security::OrchestrationPolicyConfiguration)
              .to receive(:policy_management_project?).with(project).and_return(policy_project_exists)
          end

          it { is_expected.to include(policySettingsAvailable: result) }
        end
      end

      context 'when sppRepositoryPipelineAccessLocked is locked' do
        before do
          stub_application_setting(lock_spp_repository_pipeline_access: true)
        end

        it { is_expected.to include(sppRepositoryPipelineAccessLocked: true) }
      end
    end

    describe 'Secrets Manager settings' do
      it { is_expected.to include(canManageSecretManager: false) }

      context 'when feature is licensed' do
        before do
          stub_licensed_features(native_secrets_management: true)
        end

        it { is_expected.to include(isSecretsManagerAvailable: true) }
      end

      context 'when feature is not licenced' do
        before do
          stub_licensed_features(native_secrets_management: false)
        end

        it { is_expected.to include(isSecretsManagerAvailable: false) }
      end

      context 'when ci_tanukey_ui feature flag is disabled' do
        before do
          stub_feature_flags(ci_tanukey_ui: false)
        end

        it { is_expected.to include(canManageSecretManager: false) }
      end

      context 'when ci_tanukey_ui feature flag is enabled' do
        before do
          stub_feature_flags(ci_tanukey_ui: true)
        end

        context 'when the user has admin_project_secrets_manager permission' do
          before do
            allow(helper).to receive(:can?).with(user, :admin_project_secrets_manager, project).and_return(true)
          end

          it { is_expected.to include(canManageSecretManager: true) }
        end

        context 'when the user does not have admin_project_secrets_manager permission' do
          before do
            allow(helper).to receive(:can?).with(user, :admin_project_secrets_manager, project).and_return(false)
          end

          it { is_expected.to include(canManageSecretManager: false) }
        end
      end
    end
  end

  describe '#gitlab_duo_settings_data' do
    let(:user) { instance_double(User, can_admin_all_resources?: false) }
    let(:expected_data) do
      { duoFeaturesEnabled: true, licensedAiFeaturesAvailable: false, duoFeaturesLocked: false }
    end

    subject(:data) { helper.gitlab_duo_settings_data(project) }

    before do
      allow(helper).to receive_messages(current_user: user, can?: false)
    end

    it { is_expected.to include(expected_data) }

    context "if AmazonQ is connected" do
      let_it_be(:integration) { create(:amazon_q_integration, instance: false, project: project) }

      where(
        connected: [true, false],
        auto_review_enabled: [true, false]
      )
      with_them do
        before do
          allow(::Ai::AmazonQ).to receive(:connected?).and_return(connected)
          integration.update!(auto_review_enabled: auto_review_enabled)
        end

        it 'sets amazonQAvailable to the correct value' do
          expect(data[:amazonQAvailable]).to eq(connected)
          expect(data[:amazonQAutoReviewEnabled]).to eq(auto_review_enabled)
        end
      end
    end
  end

  describe '#approvals_app_data' do
    subject(:data) { helper.approvals_app_data(project) }

    let(:user) { instance_double(User, can_admin_all_resources?: false) }

    before do
      allow(helper).to receive_messages(current_user: user, can?: true, saml_provider_enabled_for_project?: true)
    end

    it 'returns the correct data' do
      expect(data).to include(
        project_id: project.id,
        can_edit: 'true',
        can_modify_author_settings: 'true',
        can_modify_commiter_settings: 'true',
        can_read_security_policies: 'true',
        saml_provider_enabled: 'true',
        approvals_path: expose_path(api_v4_projects_merge_request_approval_setting_path(id: project.id)),
        project_path: expose_path(api_v4_projects_path(id: project.id)),
        rules_path: expose_path(api_v4_projects_approval_rules_path(id: project.id)),
        allow_multi_rule: project.multiple_approval_rules_available?.to_s,
        eligible_approvers_docs_path:
          help_page_path('user/project/merge_requests/approvals/rules.md', anchor: 'eligible-approvers'),
        security_configuration_path: project_security_configuration_path(project),
        coverage_check_help_page_path:
          help_page_path('ci/testing/code_coverage/_index.md', anchor: 'add-a-coverage-check-approval-rule'),
        group_name: project.root_ancestor.name,
        full_path: project.full_path,
        new_policy_path: expose_path(new_project_security_policy_path(project))
      )
    end
  end

  describe '#status_checks_app_data' do
    subject(:data) { helper.status_checks_app_data(project) }

    it 'returns the correct data' do
      expect(data[:data]).to eq({
        project_id: project.id,
        status_checks_path: expose_path(api_v4_projects_external_status_checks_path(id: project.id))
      })
    end
  end

  describe '#project_compliance_framework_app_data' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }

    let(:can_edit) { false }

    subject(:data) { helper.project_compliance_framework_app_data(project, can_edit) }

    before do
      allow(helper).to receive(:image_path).and_return('#empty_state_svg_path')
    end

    context 'when the user cannot edit' do
      let(:can_edit) { false }

      it 'returns the correct data' do
        expect(data).to eq({
          group_name: group.name,
          group_path: group_path(group),
          empty_state_svg_path: '#empty_state_svg_path'
        })
      end
    end

    context 'when the user can edit' do
      let(:can_edit) { true }

      it 'includes the framework edit path' do
        expect(data).to eq({
          group_name: group.name,
          group_path: group_path(group),
          empty_state_svg_path: '#empty_state_svg_path',
          add_framework_path: "#{edit_group_path(group)}#js-compliance-frameworks-settings"
        })
      end
    end
  end

  describe '#remote_mirror_setting_enabled?' do
    context 'when ci_cd_projects licensed feature is enabled' do
      before do
        stub_licensed_features(ci_cd_projects: true)
      end

      context 'when there are import sources' do
        before do
          allow(Gitlab::CurrentSettings).to receive(:import_sources).and_return(["gitlab"])
        end

        context 'when application setting mirror_available is enabled' do
          before do
            stub_application_setting(mirror_available: true)
          end

          it 'is true' do
            expect(helper.remote_mirror_setting_enabled?).to be_truthy
          end
        end

        context 'when application setting mirror_available is disabled' do
          let_it_be(:user) { create(:user) }

          before do
            allow(helper).to receive(:current_user).and_return(user)
            stub_application_setting(mirror_available: false)
          end

          context 'when mirror is not available but user is admin' do
            before do
              allow(user).to receive(:can_admin_all_resources?).and_return(true)
            end

            it 'is true' do
              expect(helper.remote_mirror_setting_enabled?).to be_truthy
            end
          end

          context 'when mirror is not available and user is not admin' do
            it 'is false' do
              expect(helper.remote_mirror_setting_enabled?).to be_falsey
            end
          end
        end
      end
    end

    context 'when ci_cd_projects licensed feature is disabled' do
      before do
        stub_licensed_features(ci_cd_projects: false)
      end

      it 'is false' do
        expect(helper.remote_mirror_setting_enabled?).to be_falsey
      end
    end
  end

  describe '#http_clone_url_to_repo' do
    let(:geo_url) { 'http://localhost/geonode_url' }
    let(:geo_node) { instance_double(GeoNode, url: geo_url) }

    subject(:url) { helper.http_clone_url_to_repo(project) }

    before do
      stub_proxied_site(geo_node)

      allow(helper).to receive(:geo_proxied_http_url_to_repo).with(geo_node, project).and_return(geo_url)
    end

    it { expect(url).to eq geo_url }
  end

  describe '#ssh_clone_url_to_repo' do
    let(:geo_url) { 'git@localhost/geonode_url' }
    let(:geo_node) { instance_double(GeoNode, url: geo_url) }

    subject(:url) { helper.ssh_clone_url_to_repo(project) }

    before do
      stub_proxied_site(geo_node)

      allow(helper).to receive(:geo_proxied_ssh_url_to_repo).with(geo_node, project).and_return(geo_url)
    end

    it { expect(url).to eq geo_url }
  end

  describe '#project_transfer_app_data' do
    it 'returns expected hash' do
      expect(helper.project_transfer_app_data(project)).to eq({
        full_path: project.full_path
      })
    end
  end

  describe '#product_analytics_settings_allowed?' do
    let_it_be(:user) { create(:user) }

    subject { helper.product_analytics_settings_allowed?(project) }

    where(:feature_enabled, :user_permission, :outcome) do
      false | false | false
      true  | false | false
      false | true  | false
      true  | true  | true
    end

    with_them do
      before do
        allow(project).to receive(:product_analytics_enabled?).and_return(feature_enabled)
        allow(helper).to receive(:current_user).and_return(user)
        allow(helper).to receive(:can?).with(user, :modify_product_analytics_settings,
          project).and_return(user_permission)
      end

      it { is_expected.to eq(outcome) }
    end
  end

  describe '#compliance_framework_data_attributes' do
    let_it_be(:user) { create(:user) }

    where(:custom_compliance_frameworks, :compliance_framework, :has_framework, :color, :name, :description,
      :expected) do
      true  | true  | true    | "#FF0000" | "Framework 1"   | "New framework" | ref(:data_attributes)
      false | true  | true    | "#00FF00" | "Framework 2"   | "Another framework" | {}
      true  | false | false   | nil | nil | nil | {}
      false | false | false   | nil | nil | nil | {}
    end

    with_them do
      before do
        stub_licensed_features(
          custom_compliance_frameworks: custom_compliance_frameworks,
          compliance_framework: compliance_framework)

        if has_framework
          framework = create(:compliance_framework,
            color: color,
            name: name,
            description: description
          )
          create(:compliance_framework_project_setting,
            project: project, compliance_management_framework: framework)
        end

        allow(helper).to receive(:current_user).and_return(user)
      end

      let(:data_attributes) do
        {
          has_compliance_framework_feature: compliance_framework.to_s,
          frameworks: [{
            compliance_framework_badge_color: color,
            compliance_framework_badge_name: name,
            compliance_framework_badge_title: description
          }]
        }
      end

      subject { helper.compliance_framework_data_attributes(project) }

      it { is_expected.to eq(expected) }
    end
  end

  describe '#pages_deployments_usage_quota_data' do
    let_it_be(:group) { create(:group) }
    let(:project) { create(:project, namespace: group) }
    let(:project2) { create(:project, namespace: group) }

    before do
      project.actual_limits.update!(active_versioned_pages_deployments_limit_by_namespace: 100)
      project2.project_setting.update!(pages_unique_domain_enabled: false)
      create(:pages_deployment, project: project, path_prefix: '/foo')
      create(:pages_deployment, project: project2, path_prefix: '/foo')
    end

    context 'when project has unique domain enabled' do
      before do
        project.project_setting.update!(pages_unique_domain_enabled: true, pages_unique_domain: 'foo123')
      end

      it 'returns expected hash' do
        expect(helper.pages_deployments_usage_quota_data(project)).to match(
          {
            full_path: project.full_path,
            project_deployments_count: 1,
            deployments_count: 1,
            deployments_limit: 100,
            domain: 'foo123.example.com',
            uses_namespace_domain: 'false'
          }
        )
      end
    end

    context 'when project has unique domain disabled' do
      before do
        project.project_setting.update!(pages_unique_domain_enabled: false)
      end

      it 'returns expected hash' do
        expect(helper.pages_deployments_usage_quota_data(project)).to match(
          {
            full_path: project.full_path,
            project_deployments_count: 1,
            deployments_count: 2,
            deployments_limit: 100,
            domain: "#{group.path}.example.com",
            uses_namespace_domain: 'true'
          }
        )
      end
    end
  end
end
