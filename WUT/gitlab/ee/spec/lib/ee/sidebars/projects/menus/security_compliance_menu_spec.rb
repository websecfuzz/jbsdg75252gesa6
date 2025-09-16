# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Projects::Menus::SecurityComplianceMenu, feature_category: :navigation do
  let_it_be(:project) { create(:project) }

  let(:user) { project.first_owner }
  let(:show_promotions) { true }
  let(:show_discover_project_security) { true }
  let(:context) { Sidebars::Projects::Context.new(current_user: user, container: project, show_promotions: show_promotions, show_discover_project_security: show_discover_project_security) }

  subject(:items) { described_class.new(context).renderable_items.find { |i| i.item_id == item_id } }

  describe '#link' do
    subject(:menu) { described_class.new(context) }

    let(:show_promotions) { false }
    let(:show_discover_project_security) { false }

    using RSpec::Parameterized::TableSyntax

    where(:show_discover_project_security, :security_dashboard_feature, :dependency_scanning_feature, :audit_events_feature, :expected_link) do
      true  | true  | true  | true  | '/-/security/discover'
      false | true  | true  | true  | '/-/security/dashboard'
      false | false | true  | true  | '/-/dependencies'
      false | false | false | true  | '/-/audit_events'
      false | false | false | false | '/-/security/configuration'
    end

    with_them do
      it 'returns the expected link' do
        stub_licensed_features(security_dashboard: security_dashboard_feature, audit_events: audit_events_feature, dependency_scanning: dependency_scanning_feature)

        expect(menu.link).to include(expected_link)
      end
    end

    context 'when no security menu item and show promotions' do
      let(:user) { nil }

      it 'returns nil', :aggregate_failures do
        expect(menu.renderable_items).to be_empty
        expect(menu.link).to be_nil
      end
    end
  end

  describe 'Menu items' do
    describe 'with read_vulnerablity custom role permission' do
      subject(:renderable_items) { described_class.new(context).renderable_items.map(&:item_id) }

      before do
        stub_licensed_features(
          security_dashboard: true, audit_events: true, dependency_scanning: true, custom_roles: true, license_scanning: true)

        create(:member_role, :guest, :read_vulnerability, namespace: project.group).tap do |role|
          role.members << create(:group_member, :guest, user: guest, source: project.group)
        end
      end

      let(:guest) { create(:user) }
      let(:context) { Sidebars::Projects::Context.new(current_user: guest, container: project, show_promotions: false, show_discover_project_security: false) }

      context 'with a public project' do
        let_it_be(:project) { create(:project, :public, :in_group) }

        it { expect(renderable_items).to match_array([:dashboard, :dependency_list, :vulnerability_report]) }
      end

      context 'with a private project' do
        let_it_be(:project) { create(:project, :private, :in_group) }

        it { expect(renderable_items).to match_array([:dashboard, :vulnerability_report]) }
      end
    end

    describe 'Configuration' do
      let(:item_id) { :configuration }

      describe '#sidebar_security_configuration_paths' do
        let(:expected_security_configuration_paths) do
          %w[
            projects/security/configuration#show
            projects/security/sast_configuration#show
            projects/security/api_fuzzing_configuration#show
            projects/security/dast_configuration#show
            projects/security/dast_profiles#show
            projects/security/dast_site_profiles#new
            projects/security/dast_site_profiles#edit
            projects/security/dast_scanner_profiles#new
            projects/security/dast_scanner_profiles#edit
            projects/security/corpus_management#show
            projects/security/secret_detection_configuration#show
          ]
        end

        it 'includes all the security configuration paths' do
          expect(subject.active_routes[:path]).to match_array expected_security_configuration_paths
        end
      end
    end

    describe 'Discover Security and compliance' do
      let(:item_id) { :discover_project_security }

      context 'when show_discover_project_security is true' do
        it { is_expected.not_to be_nil }
      end

      context 'when show_discover_project_security is not true' do
        let(:show_discover_project_security) { false }

        it { is_expected.to be_nil }
      end
    end

    describe 'Security Dashboard' do
      let(:item_id) { :dashboard }

      before do
        stub_licensed_features(security_dashboard: true)
      end

      context 'when user can access security dashboard' do
        it { is_expected.not_to be_nil }
      end

      context 'when user cannot access security dashboard' do
        let(:user) { nil }

        it { is_expected.to be_nil }
      end
    end

    describe 'Vulnerability Report' do
      let(:item_id) { :vulnerability_report }

      before do
        stub_licensed_features(security_dashboard: true)
      end

      context 'when user can access vulnerabilities report' do
        it { is_expected.not_to be_nil }
      end

      context 'when user cannot access vulnerabilities report' do
        let(:user) { nil }

        it { is_expected.to be_nil }
      end
    end

    describe 'On Demand Scans' do
      let(:item_id) { :on_demand_scans }

      before do
        stub_licensed_features(security_on_demand_scans: true)
      end

      context 'when user can access vulnerabilities report' do
        it { is_expected.not_to be_nil }
      end

      context 'when user cannot access vulnerabilities report' do
        let(:user) { nil }

        it { is_expected.to be_nil }
      end

      context 'when FIPS mode is enabled' do
        let(:user) { project.first_owner }

        before do
          allow(::Gitlab::FIPS).to receive(:enabled?).and_return(true)
          allow(Ability).to receive(:allowed?).and_call_original
          allow(Ability).to receive(:allowed?).with(user, :read_on_demand_dast_scan, project).and_return(true)
        end

        it { is_expected.not_to be_nil }
      end
    end

    describe 'Dependency List' do
      let(:item_id) { :dependency_list }

      before do
        stub_licensed_features(dependency_scanning: true)
      end

      context 'when user can access dependency list' do
        it { is_expected.not_to be_nil }
      end

      context 'when user cannot access dependency list' do
        let(:user) { nil }

        it { is_expected.to be_nil }
      end
    end

    describe 'Policies' do
      let(:item_id) { :scan_policies }

      before do
        stub_licensed_features(security_orchestration_policies: true)
      end

      context 'when user can access policies tab' do
        it { is_expected.not_to be_nil }
      end

      context 'when user cannot access policies tab' do
        let(:user) { nil }

        it { is_expected.to be_nil }
      end
    end

    describe 'Audit events' do
      let(:item_id) { :audit_events }

      context 'when user can access audit events' do
        it { is_expected.not_to be_nil }

        context 'when feature audit events is licensed' do
          before do
            stub_licensed_features(audit_events: true)
          end

          it { is_expected.not_to be_nil }
        end

        context 'when feature audit events is not licensed' do
          before do
            stub_licensed_features(audit_events: false)
          end

          context 'when show promotions is enabled' do
            it { is_expected.not_to be_nil }
          end

          context 'when show promotions is disabled' do
            let(:show_promotions) { false }

            it { is_expected.to be_nil }
          end
        end
      end

      context 'when user cannot access audit events' do
        let(:user) { nil }

        it { is_expected.to be_nil }
      end
    end

    describe 'Compliance center' do
      let(:item_id) { :compliance }

      context 'when project_level_compliance_dashboard feature is enabled' do
        before do
          stub_licensed_features(project_level_compliance_dashboard: true)
        end

        context 'when project is in personal namespace' do
          it { is_expected.to be_nil }
        end

        context 'when project is in group' do
          let_it_be(:user) { create(:user) }
          let_it_be(:project) { create(:project, :private, :in_group) }

          context 'when user is an owner' do
            before_all do
              project.add_owner(user)
            end

            it { is_expected.not_to be_nil }
          end

          context 'when user is assigned a custom role with `read_compliance_dashboard` ability' do
            let_it_be(:member_role) { create(:member_role, :guest, :read_compliance_dashboard, namespace: project.group) }
            let_it_be(:member) { create(:project_member, :guest, user: user, source: project, member_role: member_role) }

            before do
              stub_licensed_features(project_level_compliance_dashboard: true, custom_roles: true)
            end

            it { is_expected.not_to be_nil }

            context 'when custom roles feature is disabled' do
              before do
                stub_licensed_features(project_level_compliance_dashboard: true, custom_roles: false)
              end

              it { is_expected.to be_nil }
            end
          end

          context 'when user is assigned a custom role with `admin_compliance_framework` ability' do
            let_it_be(:member_role) { create(:member_role, :guest, :admin_compliance_framework, namespace: project.group) }
            let_it_be(:member) { create(:project_member, :guest, user: user, source: project, member_role: member_role) }

            before do
              stub_licensed_features(project_level_compliance_dashboard: true, custom_roles: true)
            end

            it { is_expected.not_to be_nil }

            context 'when custom roles feature is disabled' do
              before do
                stub_licensed_features(project_level_compliance_dashboard: true, custom_roles: false)
              end

              it { is_expected.to be_nil }
            end
          end
        end
      end

      context 'when project_level_compliance_dashboard feature is not enabled' do
        it { is_expected.to be_nil }
      end
    end
  end
end
