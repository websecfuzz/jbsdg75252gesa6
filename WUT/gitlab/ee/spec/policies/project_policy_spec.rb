# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProjectPolicy, feature_category: :system_access do
  include ExternalAuthorizationServiceHelpers
  include AdminModeHelper
  include_context 'ProjectPolicy context'

  using RSpec::Parameterized::TableSyntax

  let(:project) { public_project }

  let_it_be(:auditor) { create(:user, :auditor) }

  subject { described_class.new(current_user, project) }

  before do
    stub_licensed_features(
      license_scanning: true,
      quality_management: true,
      cycle_analytics_for_projects: true
    )
  end

  context 'basic permissions' do
    let(:additional_guest_permissions) { %i[read_limit_alert] }
    let(:additional_reporter_permissions) do
      %i[read_software_license_policy admin_value_stream read_product_analytics read_path_locks]
    end

    let(:additional_developer_permissions) do
      %i[
        admin_vulnerability_feedback read_project_audit_events read_project_security_dashboard
        admin_vulnerability_issue_link admin_vulnerability_external_issue_link
        read_security_resource read_vulnerability_scanner admin_vulnerability read_vulnerability
        create_vulnerability_export read_merge_train create_path_locks
      ]
    end

    let(:additional_maintainer_permissions) do
      %i[push_code_to_protected_branches]
    end

    let(:additional_owner_permissions) do
      %i[create_container_registry_protection_immutable_tag_rule]
    end

    let(:auditor_permissions) do
      %i[
        download_code download_wiki_code read_project read_project_metadata read_issue_board read_issue_board_list
        read_project_for_iids read_issue_iid read_merge_request_iid read_wiki
        read_issue read_label read_issue_link read_milestone
        read_snippet read_project_member read_note read_cycle_analytics
        read_pipeline read_build read_commit_status read_container_image
        read_environment read_deployment read_merge_request read_pages
        award_emoji
        read_project_security_dashboard read_security_resource read_vulnerability_scanner
        read_software_license_policy
        read_merge_train
        read_release
        read_project_audit_events
        read_cluster
        read_terraform_state
        read_project_merge_request_analytics
        read_on_demand_dast_scan
        read_alert_management_alert
      ]
    end

    it_behaves_like 'project policies as anonymous'
    it_behaves_like 'project policies as guest'
    it_behaves_like 'project policies as planner'
    it_behaves_like 'project policies as reporter'
    it_behaves_like 'project policies as developer'
    it_behaves_like 'project policies as maintainer'
    it_behaves_like 'project policies as owner'
    it_behaves_like 'project policies as admin with admin mode'
    it_behaves_like 'project policies as admin without admin mode'

    context 'auditor' do
      let(:current_user) { auditor }
      let(:auditor_permission_exclusions) { [:fork_project, :create_merge_request_in] }
      let(:auditor_as_guest_exclusions) do
        %i[create_note read_confidential_issues create_project create_issue create_note upload_file admin_issue_link]
      end

      before do
        stub_licensed_features(security_dashboard: true, license_scanning: true)
      end

      context 'who is not a team member' do
        it do
          is_expected.to be_disallowed(*(developer_permissions - auditor_permissions))
          is_expected.to be_disallowed(*maintainer_permissions)
          is_expected.to be_disallowed(*owner_permissions)
          is_expected.to be_disallowed(*(guest_permissions - auditor_permissions))
          is_expected.to be_disallowed(*(planner_permissions - auditor_permissions - [:read_confidential_issues]))
          is_expected.to be_allowed(*auditor_permission_exclusions)
          is_expected.to be_allowed(*auditor_permissions)
        end

        context 'with private project' do
          let(:project) { private_project }

          let(:auditor_permission_exclusions) { [:fork_project, :create_merge_request_in, :read_project_for_iids] }

          it do
            is_expected.to be_disallowed(*(developer_permissions - auditor_permissions))
            is_expected.to be_disallowed(*maintainer_permissions)
            is_expected.to be_disallowed(*owner_permissions)
            is_expected.to be_disallowed(*(guest_permissions - auditor_permissions))
            is_expected.to be_disallowed(*(planner_permissions - auditor_permissions - [:read_confidential_issues]))
            is_expected.to be_disallowed(*auditor_permission_exclusions)
            is_expected.to be_allowed(*(auditor_permissions - auditor_permission_exclusions))
          end
        end
      end

      context 'who is a team member' do
        before do
          project.add_guest(current_user)
        end

        it do
          is_expected.to be_disallowed(*(developer_permissions - auditor_permissions))
          is_expected.to be_disallowed(*maintainer_permissions)
          is_expected.to be_disallowed(*owner_permissions)
          is_expected.to be_disallowed(*(planner_permissions - auditor_permissions - auditor_as_guest_exclusions))
          is_expected.to be_allowed(*(guest_permissions - auditor_permissions))
          is_expected.to be_allowed(*auditor_permissions)
        end
      end

      it_behaves_like 'project private features with read_all_resources ability' do
        let(:user) { current_user }
      end

      context 'with project feature related policies' do
        # Required parameters:
        # - project_feature: Hash defining project feature mapping abilities.
        shared_examples 'project feature visibility' do |project_features|
          # For each project feature, check that an auditor is always allowed read
          # permissions unless the feature is disabled.
          project_features.each do |feature, permissions|
            context "with project feature #{feature}" do
              where(:project_visibility, :access_level, :allowed) do
                :public   | ProjectFeature::ENABLED  | true
                :public   | ProjectFeature::PRIVATE  | true
                :public   | ProjectFeature::DISABLED | false
                :internal | ProjectFeature::ENABLED  | true
                :internal | ProjectFeature::PRIVATE  | true
                :internal | ProjectFeature::DISABLED | false
                :private  | ProjectFeature::ENABLED  | true
                :private  | ProjectFeature::PRIVATE  | true
                :private  | ProjectFeature::DISABLED | false
              end

              with_them do
                let(:project) { send("#{project_visibility}_project") }

                it 'always allows permissions except when feature disabled' do
                  project.project_feature.update!("#{feature}": access_level)

                  if allowed
                    expect_allowed(*permissions)
                  else
                    expect_disallowed(*permissions)
                  end
                end
              end
            end
          end
        end

        include_examples 'project feature visibility', {
          container_registry_access_level: [:read_container_image],
          merge_requests_access_level: [:read_merge_request],
          monitor_access_level: [:read_alert_management_alert]
        }
      end
    end
  end

  context 'iterations' do
    context 'in a personal project' do
      let(:current_user) { owner }

      context 'when feature is disabled' do
        before do
          stub_licensed_features(iterations: false)
        end

        it { is_expected.to be_disallowed(:read_iteration, :create_iteration, :admin_iteration) }
      end

      context 'when feature is enabled' do
        before do
          stub_licensed_features(iterations: true)
        end

        it { is_expected.to be_disallowed(:read_iteration, :create_iteration, :admin_iteration) }
      end
    end

    context 'in a group project' do
      let(:project) { public_project_in_group }
      let(:current_user) { maintainer }

      context 'when feature is disabled' do
        before do
          stub_licensed_features(iterations: false)
        end

        it { is_expected.to be_disallowed(:read_iteration, :create_iteration, :admin_iteration) }
      end

      context 'when feature is enabled' do
        before do
          stub_licensed_features(iterations: true)
        end

        it { is_expected.to be_allowed(:read_iteration, :create_iteration, :admin_iteration) }

        context 'when issues are disabled but merge requests are enabled' do
          before do
            project.update!(issues_enabled: false)
          end

          it { is_expected.to be_allowed(:read_iteration, :create_iteration, :admin_iteration) }
        end

        context 'when issues are enabled but merge requests are enabled' do
          before do
            project.update!(merge_requests_enabled: false)
          end

          it { is_expected.to be_allowed(:read_iteration, :create_iteration, :admin_iteration) }
        end

        context 'when both issues and merge requests are disabled' do
          before do
            project.update!(issues_enabled: false, merge_requests_enabled: false)
          end

          it { is_expected.to be_disallowed(:read_iteration, :create_iteration, :admin_iteration) }
        end

        where(:the_user, :allowed, :disallowed) do
          ref(:developer)  | [:read_iteration, :create_iteration, :admin_iteration] | []
          ref(:planner)    | [:read_iteration, :create_iteration, :admin_iteration] | []
          ref(:guest)      | [:read_iteration]                                      | [:create_iteration, :admin_iteration]
          ref(:non_member) | [:read_iteration]                                      | [:create_iteration, :admin_iteration]
          ref(:anonymous)  | [:read_iteration]                                      | [:create_iteration, :admin_iteration]
        end

        with_them do
          let(:current_user) { the_user }

          it { is_expected.to be_allowed(*allowed) }
          it { is_expected.to be_disallowed(*disallowed) }
        end

        context 'when the project is private' do
          let(:project) { private_project }

          context 'when user is not a member' do
            let(:current_user) { non_member }

            it { is_expected.to be_disallowed(:read_iteration, :create_iteration, :admin_iteration) }
          end

          context 'when user is logged out' do
            let(:current_user) { anonymous }

            it { is_expected.to be_disallowed(:read_iteration, :create_iteration, :admin_iteration) }
          end
        end
      end
    end
  end

  context 'issues feature' do
    let(:current_user) { owner }

    context 'when the feature is disabled' do
      before do
        project.update!(issues_enabled: false)
      end

      it 'disables boards permissions' do
        expect_disallowed :admin_issue_board, :create_test_case
      end

      it 'disables issues analytics' do
        expect_disallowed :read_issues_analytics
      end
    end
  end

  context 'merge requests feature' do
    let(:current_user) { owner }
    let_it_be(:group) { create(:group, :private) }
    let_it_be(:project) { create(:project, group: group) }

    context 'when the feature is disabled' do
      before do
        project.update!(merge_requests_enabled: false)
      end

      it 'disables issues analytics' do
        expect_disallowed :read_project_merge_request_analytics
      end
    end
  end

  context 'admin_mirror' do
    context 'with remote mirror setting enabled' do
      context 'with admin' do
        let(:current_user) { admin }

        context 'when admin mode enabled', :enable_admin_mode do
          it { is_expected.to be_allowed(:admin_mirror) }
        end

        context 'when admin mode disabled' do
          it { is_expected.to be_disallowed(:admin_mirror) }
        end
      end

      context 'with owner' do
        let(:current_user) { owner }

        it { is_expected.to be_allowed(:admin_mirror) }
      end

      context 'with developer' do
        let(:current_user) { developer }

        it { is_expected.to be_disallowed(:admin_mirror) }
      end
    end

    context 'with remote mirror setting disabled' do
      before do
        stub_application_setting(mirror_available: false)
      end

      context 'with admin' do
        let(:current_user) { admin }

        context 'when admin mode enabled', :enable_admin_mode do
          it { is_expected.to be_allowed(:admin_mirror) }
        end

        context 'when admin mode disabled' do
          it { is_expected.to be_disallowed(:admin_mirror) }
        end
      end

      context 'with owner' do
        let(:current_user) { owner }

        it { is_expected.to be_disallowed(:admin_mirror) }
      end
    end

    context 'with remote mirrors feature disabled' do
      before do
        stub_licensed_features(repository_mirrors: false)
      end

      context 'with admin' do
        let(:current_user) { admin }

        it { is_expected.to be_disallowed(:admin_mirror) }
      end

      context 'with owner' do
        let(:current_user) { owner }

        it { is_expected.to be_disallowed(:admin_mirror) }
      end
    end

    context 'with remote mirrors feature enabled' do
      before do
        stub_licensed_features(repository_mirrors: true)
      end

      context 'with admin' do
        let(:current_user) { admin }

        context 'when admin mode enabled', :enable_admin_mode do
          it { is_expected.to be_allowed(:admin_mirror) }
        end

        context 'when admin mode disabled' do
          it { is_expected.to be_disallowed(:admin_mirror) }
        end
      end

      context 'with owner' do
        let(:current_user) { owner }

        it { is_expected.to be_allowed(:admin_mirror) }
      end
    end
  end

  context 'reading a project' do
    context 'with an external authorization service' do
      before do
        enable_external_authorization_service_check
      end

      it 'allows auditors' do
        stub_licensed_features(auditor_user: true)
        auditor = create(:user, :auditor)

        expect(described_class.new(auditor, project)).to be_allowed(:read_project)
      end
    end

    context 'when SAML SSO is enabled for resource' do
      let(:saml_provider) { create(:saml_provider, enabled: true, enforced_sso: false) }
      let(:identity) { create(:group_saml_identity, saml_provider: saml_provider) }
      let(:root_group) { saml_provider.group }
      let(:project) { create(:project, group: root_group) }
      let(:member_with_identity) { identity.user }
      let(:member_without_identity) { create(:user) }
      let(:project_member_without_identity) { create(:user) }
      let(:non_member) { create(:user) }
      let(:not_signed_in_user) { nil }

      before do
        stub_licensed_features(group_saml: true)
        root_group.add_developer(member_with_identity)
        root_group.add_developer(member_without_identity)
        project.add_developer(project_member_without_identity)
      end

      subject { described_class.new(current_user, resource) }

      shared_examples 'does not allow read project' do
        it 'does not allow read project' do
          is_expected.not_to allow_action(:read_project)
        end
      end

      shared_examples 'allows to read project' do
        it 'allows read project' do
          is_expected.to allow_action(:read_project)
        end
      end

      shared_examples 'does not allow to read project due to its visibility level' do
        it 'does not allow to read project due to its visibility level', :aggregate_failures do
          expect(resource.root_ancestor.saml_provider.enforced_sso?).to eq(false)

          is_expected.not_to allow_action(:read_project)
        end
      end

      # See https://docs.gitlab.com/ee/user/group/saml_sso/#sso-enforcement
      where(:resource, :resource_visibility_level, :enforced_sso?, :user, :user_is_resource_owner?, :user_with_saml_session?, :user_is_admin?, :enable_admin_mode?, :user_is_auditor?, :shared_examples) do
        # Project/Group visibility: Private; Enforce SSO setting: Off

        ref(:project)    | 'private' | false | ref(:member_with_identity)    | false | false | nil  | nil   | nil  | 'does not allow read project'
        ref(:project)    | 'private' | false | ref(:member_with_identity)    | true  | false | nil  | nil   | nil  | 'does not allow read project'
        ref(:project)    | 'private' | false | ref(:member_with_identity)    | false | true  | nil  | nil   | nil  | 'allows to read project'
        ref(:project)    | 'private' | false | ref(:member_with_identity)    | false | false | true | false | nil  | 'does not allow read project'
        ref(:project)    | 'private' | false | ref(:member_with_identity)    | false | false | true | true  | nil  | 'allows to read project'
        ref(:project)    | 'private' | false | ref(:member_with_identity)    | false | false | nil  | nil   | true | 'allows to read project'

        ref(:project)    | 'private' | false | ref(:member_without_identity) | false | nil   | nil  | nil   | nil  | 'allows to read project'

        ref(:project)    | 'private' | false | ref(:non_member)              | nil   | nil   | nil  | nil   | nil  | 'does not allow to read project due to its visibility level'
        ref(:project)    | 'private' | false | ref(:non_member)              | nil   | nil   | true | false | nil  | 'does not allow to read project due to its visibility level'
        ref(:project)    | 'private' | false | ref(:non_member)              | nil   | nil   | true | true  | nil  | 'allows to read project'
        ref(:project)    | 'private' | false | ref(:non_member)              | nil   | nil   | nil  | nil   | true | 'allows to read project'
        ref(:project)    | 'private' | false | ref(:not_signed_in_user)      | nil   | nil   | nil  | nil   | nil  | 'does not allow to read project due to its visibility level'

        # Project/Group visibility: Private; Enforce SSO setting: On

        ref(:project)    | 'private' | true  | ref(:member_with_identity)    | false | false | nil  | nil   | nil  | 'does not allow read project'
        ref(:project)    | 'private' | true  | ref(:member_with_identity)    | true  | false | nil  | nil   | nil  | 'does not allow read project'
        ref(:project)    | 'private' | true  | ref(:member_with_identity)    | false | true  | nil  | nil   | nil  | 'allows to read project'
        ref(:project)    | 'private' | true  | ref(:member_with_identity)    | false | false | true | false | nil  | 'does not allow read project'
        ref(:project)    | 'private' | true  | ref(:member_with_identity)    | false | false | true | true  | nil  | 'allows to read project'
        ref(:project)    | 'private' | true  | ref(:member_with_identity)    | false | false | nil  | nil   | true | 'allows to read project'

        ref(:project)    | 'private' | true  | ref(:member_without_identity) | false | nil   | nil  | nil   | nil  | 'does not allow read project'
        ref(:project)    | 'private' | true  | ref(:member_without_identity) | true  | nil   | nil  | nil   | nil  | 'does not allow read project'
        ref(:project)    | 'private' | true  | ref(:member_without_identity) | false | nil   | true | false | nil  | 'does not allow read project'
        ref(:project)    | 'private' | true  | ref(:member_without_identity) | false | nil   | true | true  | nil  | 'allows to read project'
        ref(:project)    | 'private' | true  | ref(:member_without_identity) | false | nil   | nil  | nil   | true | 'allows to read project'

        ref(:project)    | 'private' | true  | ref(:project_member_without_identity) | false | nil   | nil  | nil   | nil  | 'does not allow read project'
        ref(:project)    | 'private' | true  | ref(:project_member_without_identity) | false | nil   | true | false | nil  | 'does not allow read project'
        ref(:project)    | 'private' | true  | ref(:project_member_without_identity) | false | nil   | true | true  | nil  | 'allows to read project'
        ref(:project)    | 'private' | true  | ref(:project_member_without_identity) | false | nil   | nil  | nil   | true | 'allows to read project'

        ref(:project)    | 'private' | true  | ref(:non_member)              | nil   | nil   | nil  | nil   | nil  | 'does not allow read project'
        ref(:project)    | 'private' | true  | ref(:non_member)              | nil   | nil   | true | false | nil  | 'does not allow read project'
        ref(:project)    | 'private' | true  | ref(:non_member)              | nil   | nil   | true | true  | nil  | 'allows to read project'
        ref(:project)    | 'private' | true  | ref(:non_member)              | nil   | nil   | nil  | nil   | true | 'allows to read project'
        ref(:project)    | 'private' | true  | ref(:not_signed_in_user)      | nil   | nil   | nil  | nil   | nil  | 'does not allow read project'

        # Project/Group visibility: Public; Enforce SSO setting: Off

        ref(:project)    | 'public'  | false | ref(:member_with_identity)    | false | false | nil  | nil   | nil  | 'does not allow read project'
        ref(:project)    | 'public'  | false | ref(:member_with_identity)    | true  | false | nil  | nil   | nil  | 'does not allow read project'
        ref(:project)    | 'public'  | false | ref(:member_with_identity)    | false | true  | nil  | nil   | nil  | 'allows to read project'
        ref(:project)    | 'public'  | false | ref(:member_with_identity)    | false | false | true | false | nil  | 'does not allow read project'
        ref(:project)    | 'public'  | false | ref(:member_with_identity)    | false | false | true | true  | nil  | 'allows to read project'
        ref(:project)    | 'public'  | false | ref(:member_with_identity)    | false | false | nil  | nil   | true | 'allows to read project'

        ref(:project)    | 'public'  | false | ref(:member_without_identity) | false | nil   | nil  | nil   | nil  | 'allows to read project'

        ref(:project)    | 'public'  | false | ref(:non_member)              | nil   | nil   | nil  | nil   | nil  | 'allows to read project'
        ref(:project)    | 'public'  | false | ref(:not_signed_in_user)      | nil   | nil   | nil  | nil   | nil  | 'allows to read project'

        # Project/Group visibility: Public; Enforce SSO setting: On

        ref(:project)    | 'public'  | true  | ref(:member_with_identity)    | false | false | nil  | nil   | nil  | 'does not allow read project'
        ref(:project)    | 'public'  | true  | ref(:member_with_identity)    | true  | false | nil  | nil   | nil  | 'does not allow read project'
        ref(:project)    | 'public'  | true  | ref(:member_with_identity)    | false | true  | nil  | nil   | nil  | 'allows to read project'
        ref(:project)    | 'public'  | true  | ref(:member_with_identity)    | false | false | true | false | nil  | 'does not allow read project'
        ref(:project)    | 'public'  | true  | ref(:member_with_identity)    | false | false | true | true  | nil  | 'allows to read project'
        ref(:project)    | 'public'  | true  | ref(:member_with_identity)    | false | false | nil  | nil   | true | 'allows to read project'

        ref(:project)    | 'public'  | true  | ref(:member_without_identity) | false | nil   | nil  | nil   | nil  | 'does not allow read project'
        ref(:project)    | 'public'  | true  | ref(:member_without_identity) | true  | nil   | nil  | nil   | nil  | 'does not allow read project'
        ref(:project)    | 'public'  | true  | ref(:member_without_identity) | false | nil   | true | false | nil  | 'does not allow read project'
        ref(:project)    | 'public'  | true  | ref(:member_without_identity) | false | nil   | true | true  | nil  | 'allows to read project'
        ref(:project)    | 'public'  | true  | ref(:member_without_identity) | false | nil   | nil  | nil   | true | 'allows to read project'

        ref(:project)    | 'public' | true  | ref(:project_member_without_identity) | false | nil   | nil  | nil   | nil  | 'does not allow read project'
        ref(:project)    | 'public' | true  | ref(:project_member_without_identity) | false | nil   | true | false | nil  | 'does not allow read project'
        ref(:project)    | 'public' | true  | ref(:project_member_without_identity) | false | nil   | true | true  | nil  | 'allows to read project'
        ref(:project)    | 'public' | true  | ref(:project_member_without_identity) | false | nil   | nil  | nil   | true | 'allows to read project'

        ref(:project)    | 'public'  | true  | ref(:non_member)              | nil   | nil   | nil  | nil   | nil  | 'allows to read project'
        ref(:project)    | 'public'  | true  | ref(:not_signed_in_user)      | nil   | nil   | nil  | nil   | nil  | 'allows to read project'
      end

      with_them do
        context "when 'Enforce SSO-only authentication for web activity for this group' option is #{params[:enforced_sso?] ? 'enabled' : 'not enabled'}" do
          around do |example|
            session = {}

            session['warden.user.user.key'] = [[user.id], user.authenticatable_salt] if user.is_a?(User)

            Gitlab::Session.with_session(session) do
              example.run
            end
          end

          before do
            saml_provider.update!(enforced_sso: enforced_sso?)
          end

          context "when resource is #{params[:resource_visibility_level]}" do
            before do
              resource.update!(visibility_level: Gitlab::VisibilityLevel.string_options[resource_visibility_level])
            end

            context 'for user', enable_admin_mode: params[:enable_admin_mode?] do
              before do
                if user_is_resource_owner?
                  resource.root_ancestor.member(user).update_column(:access_level, Gitlab::Access::OWNER)
                end

                Gitlab::Auth::GroupSaml::SsoEnforcer.new(saml_provider).update_session if user_with_saml_session?

                user.update!(admin: true) if user_is_admin?
                user.update!(auditor: true) if user_is_auditor?
              end

              let(:current_user) { user }

              include_examples params[:shared_examples]
            end
          end
        end
      end
    end

    context 'with ip restriction' do
      let(:current_user) { create(:admin) }
      let(:group) { create(:group, :public) }
      let(:project) { create(:project, group: group) }

      before do
        allow(Gitlab::IpAddressState).to receive(:current).and_return('192.168.0.2')
        stub_licensed_features(group_ip_restriction: true)
        group.add_maintainer(current_user)
      end

      context 'group without restriction' do
        it { is_expected.to be_allowed(:read_project) }
        it { is_expected.to be_allowed(:read_issue) }
        it { is_expected.to be_allowed(:read_merge_request) }
        it { is_expected.to be_allowed(:read_milestone) }
        it { is_expected.to be_allowed(:read_container_image) }
        it { is_expected.to be_allowed(:read_package) }
        it { is_expected.to be_allowed(:create_package) }
        it { is_expected.to be_allowed(:destroy_package) }
        it { is_expected.to be_allowed(:admin_package) }
      end

      context 'group with restriction' do
        before do
          create(:ip_restriction, group: group, range: range)
        end

        context 'address is within the range' do
          let(:range) { '192.168.0.0/24' }

          it { is_expected.to be_allowed(:read_project) }
          it { is_expected.to be_allowed(:read_issue) }
          it { is_expected.to be_allowed(:read_merge_request) }
          it { is_expected.to be_allowed(:read_milestone) }
          it { is_expected.to be_allowed(:read_container_image) }
          it { is_expected.to be_allowed(:create_container_image) }
          it { is_expected.to be_allowed(:read_package) }
          it { is_expected.to be_allowed(:create_package) }
          it { is_expected.to be_allowed(:destroy_package) }
          it { is_expected.to be_allowed(:admin_package) }
        end

        context 'address is outside the range' do
          let(:range) { '10.0.0.0/8' }

          it { is_expected.to be_disallowed(:read_project) }
          it { is_expected.to be_disallowed(:read_issue) }
          it { is_expected.to be_disallowed(:read_merge_request) }
          it { is_expected.to be_disallowed(:read_milestone) }
          it { is_expected.to be_disallowed(:read_container_image) }
          it { is_expected.to be_disallowed(:create_container_image) }
          it { is_expected.to be_disallowed(:read_package) }
          it { is_expected.to be_disallowed(:create_package) }
          it { is_expected.to be_disallowed(:destroy_package) }
          it { is_expected.to be_disallowed(:admin_package) }

          context 'with admin enabled', :enable_admin_mode do
            it { is_expected.to be_allowed(:read_project) }
            it { is_expected.to be_allowed(:read_issue) }
            it { is_expected.to be_allowed(:read_merge_request) }
            it { is_expected.to be_allowed(:read_milestone) }
            it { is_expected.to be_allowed(:read_container_image) }
            it { is_expected.to be_allowed(:create_container_image) }
            it { is_expected.to be_allowed(:read_package) }
            it { is_expected.to be_allowed(:create_package) }
            it { is_expected.to be_allowed(:destroy_package) }
            it { is_expected.to be_allowed(:admin_package) }
          end

          context 'with admin disabled' do
            it { is_expected.to be_disallowed(:read_project) }
            it { is_expected.to be_disallowed(:read_issue) }
            it { is_expected.to be_disallowed(:read_merge_request) }
            it { is_expected.to be_disallowed(:read_milestone) }
            it { is_expected.to be_disallowed(:read_container_image) }
            it { is_expected.to be_disallowed(:create_container_image) }
            it { is_expected.to be_disallowed(:read_package) }
            it { is_expected.to be_disallowed(:create_package) }
            it { is_expected.to be_disallowed(:destroy_package) }
            it { is_expected.to be_disallowed(:admin_package) }
          end

          context 'with auditor' do
            let(:current_user) { create(:user, :auditor) }

            it { is_expected.to be_allowed(:read_project) }
            it { is_expected.to be_allowed(:read_issue) }
            it { is_expected.to be_allowed(:read_merge_request) }
            it { is_expected.to be_allowed(:read_milestone) }
            it { is_expected.to be_allowed(:read_container_image) }
            it { is_expected.to be_allowed(:create_container_image) }
            it { is_expected.to be_allowed(:read_package) }
            it { is_expected.to be_allowed(:create_package) }
            it { is_expected.to be_allowed(:destroy_package) }
            it { is_expected.to be_allowed(:admin_package) }
          end
        end
      end

      context 'without group' do
        let(:project) { create(:project, :repository, namespace: current_user.namespace) }

        it { is_expected.to be_allowed(:read_project) }
      end
    end
  end

  describe 'access_security_and_compliance' do
    shared_examples 'correct access to security and compliance' do
      before do
        project.project_feature.update!(security_and_compliance_access_level: access_level)
      end

      context 'when "Security and compliance" is disabled' do
        let(:access_level) { Featurable::DISABLED }

        it { is_expected.to be_disallowed(:access_security_and_compliance) }
        it { is_expected.to be_disallowed(:admin_vulnerability) }
        it { is_expected.to be_disallowed(:read_vulnerability) }
      end

      context 'when "Security and compliance" is enabled' do
        let(:access_level) { Featurable::PRIVATE }

        it { is_expected.to be_allowed(:access_security_and_compliance) }
      end
    end

    context 'when the user is developer' do
      let(:current_user) { developer }

      it_behaves_like 'correct access to security and compliance'
    end

    context 'when the user has a custom role that enables read_vulnerability' do
      let(:current_user) { guest }
      let_it_be(:project) { create(:project, :in_group) }

      before do
        stub_licensed_features(custom_roles: true)
        project_member = create(:project_member, :guest, user: current_user, source: project)
        create(:member_role, :guest, read_vulnerability: true, members: [project_member], namespace: project.group)
      end

      it_behaves_like 'correct access to security and compliance'
    end

    context 'when the user is auditor' do
      let(:current_user) { create(:user, :auditor) }

      it_behaves_like 'correct access to security and compliance'
    end

    describe 'vulnerability feedback permissions' do
      before do
        stub_licensed_features(security_dashboard: true)
      end

      context 'with developer' do
        let(:current_user) { developer }

        it { is_expected.to be_allowed(:read_vulnerability_feedback) }
        it { is_expected.to be_disallowed(:create_vulnerability_feedback) }
        it { is_expected.to be_disallowed(:update_vulnerability_feedback) }
        it { is_expected.to be_disallowed(:destroy_vulnerability_feedback) }
      end

      where(permission: %i[
        read_vulnerability_feedback
              create_vulnerability_feedback
              update_vulnerability_feedback
              destroy_vulnerability_feedback
      ])

      with_them do
        context 'with admin' do
          let(:current_user) { admin }

          context 'when admin mode enabled', :enable_admin_mode do
            it { is_expected.to be_allowed(permission) }
          end

          context 'when admin mode disabled' do
            it { is_expected.to be_disallowed(permission) }
          end
        end

        %w[owner maintainer].each do |role|
          context "with #{role}" do
            let(:current_user) { send(role) }

            it { is_expected.to be_allowed(permission) }
          end
        end

        %w[anonymous non_member guest planner reporter].each do |role|
          context "with #{role}" do
            let(:current_user) { send(role) }

            it { is_expected.to be_disallowed(permission) }
          end
        end
      end
    end

    shared_context 'when security dashboard feature is not available' do
      before do
        stub_licensed_features(security_dashboard: false)
      end
    end

    describe 'read_project_security_dashboard' do
      context 'with developer' do
        let(:current_user) { developer }

        include_context 'when security dashboard feature is not available'

        it { is_expected.to be_disallowed(:read_project_security_dashboard) }
      end
    end

    describe 'vulnerability permissions' do
      context 'with developer' do
        let(:current_user) { developer }

        include_context 'when security dashboard feature is not available'

        it { is_expected.to be_disallowed(:admin_vulnerability) }
        it { is_expected.to be_disallowed(:read_vulnerability) }
        it { is_expected.to be_disallowed(:create_vulnerability_export) }
        it { is_expected.to be_disallowed(:create_vulnerability_archive_export) }
      end
    end

    describe 'permissions for security bot' do
      let_it_be(:current_user) { create(:user, :security_bot) }

      let(:project) { private_project }

      let(:permissions) do
        %i[
          reporter_access
          push_code
          create_merge_request_from
          create_merge_request_in
          create_vulnerability_feedback
          read_project
          admin_merge_request
        ]
      end

      context 'when project does not have a security_setting' do
        before do
          project.security_setting.delete
          project.reload
        end

        it { is_expected.to be_allowed(*permissions) }

        context 'with user other than security bot' do
          let_it_be(:current_user) { create(:user) }

          it { is_expected.to be_disallowed(*permissions) }
        end
      end
    end

    describe 'security orchestration policies' do
      before do
        stub_licensed_features(security_orchestration_policies: true)
      end

      context 'with developer or maintainer role' do
        where(role: %w[maintainer developer])

        with_them do
          let(:current_user) { public_send(role) }

          it { is_expected.to be_allowed(:read_security_orchestration_policies) }
          it { is_expected.to be_disallowed(:update_security_orchestration_policy_project) }
        end
      end

      context 'with owner role' do
        where(role: %w[owner])

        with_them do
          let(:current_user) { public_send(role) }

          it { is_expected.to be_allowed(:read_security_orchestration_policies) }
          it { is_expected.to be_allowed(:update_security_orchestration_policy_project) }
          it { is_expected.to be_allowed(:modify_security_policy) }

          context 'when security_orchestration_policy_configuration is present' do
            let_it_be(:security_policy_management_project) { create(:project) }

            before do
              create(:security_orchestration_policy_configuration, project: project, security_policy_management_project: security_policy_management_project)
            end

            it { is_expected.to be_disallowed(:modify_security_policy) }
          end
        end
      end

      context 'with auditor role' do
        where(role: %w[auditor])

        before do
          project.project_feature.update!(security_orchestration_policies: feature_status)
        end

        context 'with policy feature enabled' do
          let(:feature_status) { ProjectFeature::ENABLED }

          with_them do
            let(:current_user) { public_send(role) }

            it { is_expected.to be_allowed(:read_security_orchestration_policies) }
            it { is_expected.to be_disallowed(:update_security_orchestration_policy_project) }
          end
        end

        context 'with policy feature disabled' do
          let(:feature_status) { ProjectFeature::DISABLED }

          with_them do
            let(:current_user) { public_send(role) }

            it { is_expected.to be_disallowed(:read_security_orchestration_policies) }
            it { is_expected.to be_disallowed(:update_security_orchestration_policy_project) }
          end
        end
      end

      context 'when security_orchestration_policy_configuration is present' do
        let_it_be(:security_policy_management_project) { create(:project) }
        let(:current_user) { developer }

        before do
          create(:security_orchestration_policy_configuration, project: project, security_policy_management_project: security_policy_management_project)
        end

        context 'when current_user is guest of security_policy_management_project' do
          let(:project) { security_policy_management_project }

          before do
            security_policy_management_project.add_guest(developer)
          end

          it { is_expected.to be_disallowed(:read_security_orchestration_policy_project) }
          it { is_expected.to be_disallowed(:modify_security_policy) }
        end

        context 'when current_user is reporter of security_policy_management_project' do
          let(:project) { security_policy_management_project }

          before do
            security_policy_management_project.add_reporter(developer)
          end

          it { is_expected.to be_allowed(:read_security_orchestration_policy_project) }
          it { is_expected.to be_disallowed(:modify_security_policy) }
        end

        context 'when current_user is developer of security_policy_management_project' do
          let(:project) { security_policy_management_project }

          before do
            security_policy_management_project.add_developer(developer)
          end

          it { is_expected.to be_allowed(:modify_security_policy) }
        end

        context 'when current_user is not member of security_policy_management_project' do
          let(:project) { security_policy_management_project }

          it { is_expected.to be_disallowed(:read_security_orchestration_policy_project) }
          it { is_expected.to be_disallowed(:modify_security_policy) }
        end
      end
    end

    describe 'coverage_fuzzing' do
      context 'when coverage_fuzzing feature is available' do
        before do
          stub_licensed_features(coverage_fuzzing: true)
        end

        context 'with developer or higher role' do
          where(role: %w[owner maintainer developer])

          with_them do
            let(:current_user) { public_send(role) }

            it { is_expected.to be_allowed(:read_coverage_fuzzing) }
          end
        end

        context 'with admin' do
          let(:current_user) { admin }

          context 'when admin mode enabled', :enable_admin_mode do
            it { is_expected.to be_allowed(:read_coverage_fuzzing) }
          end

          context 'when admin mode disabled' do
            it { is_expected.to be_disallowed(:read_coverage_fuzzing) }
          end
        end

        context 'with less than developer role' do
          where(role: %w[reporter planner guest])

          with_them do
            let(:current_user) { public_send(role) }

            it { is_expected.to be_disallowed(:read_coverage_fuzzing) }
          end
        end

        context 'with non member' do
          let(:current_user) { non_member }

          it { is_expected.to be_disallowed(:read_coverage_fuzzing) }
        end

        context 'with anonymous' do
          let(:current_user) { anonymous }

          it { is_expected.to be_disallowed(:read_coverage_fuzzing) }
        end
      end

      context 'when coverage fuzzing feature is not available' do
        let(:current_user) { admin }

        before do
          stub_licensed_features(coverage_fuzzing: true)
        end

        it { is_expected.to be_disallowed(:read_coverage_fuzzing) }
      end
    end

    describe 'remove_project when default_project_deletion_protection is set to true' do
      before do
        stub_application_setting(default_project_deletion_protection: true)
      end

      context 'with admin' do
        let(:current_user) { admin }

        context 'when admin mode enabled', :enable_admin_mode do
          it { is_expected.to be_allowed(:remove_project) }
        end

        context 'when admin mode disabled' do
          it { is_expected.to be_disallowed(:remove_project) }

          context 'and admin owns the project' do
            let_it_be(:project) { create(:project, :public, namespace: admin.namespace) }

            it { is_expected.to be_disallowed(:remove_project) }
          end
        end
      end

      context 'with owner' do
        let(:current_user) { owner }

        it { is_expected.to be_disallowed(:remove_project) }
      end
    end

    describe 'admin_feature_flags_issue_links' do
      before do
        stub_licensed_features(feature_flags_related_issues: true)
      end

      context 'with maintainer' do
        let(:current_user) { maintainer }

        it { is_expected.to be_allowed(:admin_feature_flags_issue_links) }

        context 'when repository is disabled' do
          before do
            project.project_feature.update!(
              merge_requests_access_level: ProjectFeature::DISABLED,
              builds_access_level: ProjectFeature::DISABLED,
              repository_access_level: ProjectFeature::DISABLED
            )
          end

          it { is_expected.to be_disallowed(:admin_feature_flags_issue_links) }
        end
      end

      context 'with developer' do
        let(:current_user) { developer }

        it { is_expected.to be_allowed(:admin_feature_flags_issue_links) }

        context 'when feature is unlicensed' do
          before do
            stub_licensed_features(feature_flags_related_issues: false)
          end

          it { is_expected.to be_disallowed(:admin_feature_flags_issue_links) }
        end
      end

      context 'with reporter' do
        let(:current_user) { reporter }

        it { is_expected.to be_disallowed(:admin_feature_flags_issue_links) }
      end
    end

    describe 'admin_software_license_policy' do
      context 'without license scanning feature available' do
        before do
          stub_licensed_features(license_scanning: false)
        end

        let(:current_user) { admin }

        it { is_expected.to be_disallowed(:admin_software_license_policy) }
      end

      context 'with admin' do
        let(:current_user) { admin }

        context 'when admin mode enabled', :enable_admin_mode do
          it { is_expected.to be_allowed(:admin_software_license_policy) }
        end

        context 'when admin mode disabled' do
          it { is_expected.to be_disallowed(:admin_software_license_policy) }
        end
      end

      %w[owner maintainer].each do |role|
        context "with #{role}" do
          let(:current_user) { send(role) }

          it { is_expected.to be_allowed(:admin_software_license_policy) }
        end
      end

      %w[anonymous non_member guest planner reporter developer].each do |role|
        context "with #{role}" do
          let(:current_user) { send(role) }

          it { is_expected.to be_disallowed(:admin_software_license_policy) }
        end
      end
    end

    describe 'read_software_license_policy' do
      context 'without license scanning feature available' do
        before do
          stub_licensed_features(license_scanning: false)
        end

        let(:current_user) { admin }

        it { is_expected.to be_disallowed(:read_software_license_policy) }
      end
    end

    describe 'read_dependency' do
      context 'when dependency scanning feature available' do
        before do
          stub_licensed_features(dependency_scanning: true)
        end

        context 'with public project' do
          let(:current_user) { create(:user) }

          context 'with public access to repository' do
            let(:project) { public_project }

            it { is_expected.to be_allowed(:read_dependency) }
          end

          context 'with limited access to repository' do
            let(:project) { create(:project, :public, :repository_private) }

            it { is_expected.not_to be_allowed(:read_dependency) }
          end
        end

        context 'with private project' do
          let(:project) { private_project }

          context 'with admin' do
            let(:current_user) { admin }

            context 'when admin mode enabled', :enable_admin_mode do
              it { is_expected.to be_allowed(:read_dependency) }
            end

            context 'when admin mode disabled' do
              it { is_expected.to be_disallowed(:read_dependency) }
            end
          end

          %w[owner maintainer developer reporter].each do |role|
            context "with #{role}" do
              let(:current_user) { send(role) }

              it { is_expected.to be_allowed(:read_dependency) }
            end
          end

          %w[anonymous non_member guest planner].each do |role|
            context "with #{role}" do
              let(:current_user) { send(role) }

              it { is_expected.to be_disallowed(:read_dependency) }
            end
          end
        end
      end

      context 'when dependency list feature not available' do
        let(:current_user) { admin }

        it { is_expected.not_to be_allowed(:read_dependency) }
      end
    end

    describe 'read_licenses' do
      context 'when license management feature available' do
        context 'with public project' do
          let(:current_user) { non_member }

          context 'with public access to repository' do
            it { is_expected.to be_allowed(:read_licenses) }
          end
        end

        context 'with private project' do
          let(:project) { private_project }

          where(role: %w[owner maintainer developer reporter])

          with_them do
            let(:current_user) { public_send(role) }

            it { is_expected.to be_allowed(:read_licenses) }
          end

          context 'with admin' do
            let(:current_user) { admin }

            context 'when admin mode enabled', :enable_admin_mode do
              it { is_expected.to be_allowed(:read_licenses) }
            end

            context 'when admin mode disabled' do
              it { is_expected.to be_disallowed(:read_licenses) }
            end
          end

          %w[anonymous non_member guest planner].each do |role|
            context "with #{role}" do
              let(:current_user) { send(role) }

              it { is_expected.to be_disallowed(:read_licenses) }
            end
          end
        end
      end

      context 'when license management feature in not available' do
        before do
          stub_licensed_features(license_scanning: false)
        end

        let(:current_user) { admin }

        it { is_expected.to be_disallowed(:read_licenses) }
      end
    end

    describe 'publish_status_page' do
      let(:feature) { :status_page }
      let(:policy) { :publish_status_page }

      context 'when feature is available' do
        where(:role, :admin_mode, :allowed) do
          :anonymous  | nil   | false
          :guest      | nil   | false
          :planner    | nil   | false
          :reporter   | nil   | false
          :developer  | nil   | true
          :maintainer | nil   | true
          :owner      | nil   | true
          :admin      | false | false
          :admin      | true  | true
        end

        with_them do
          let(:current_user) { public_send(role) if role }

          before do
            stub_licensed_features(feature => true)
            enable_admin_mode!(current_user) if admin_mode
          end

          it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }

          context 'when feature is not available' do
            before do
              stub_licensed_features(feature => false)
            end

            it { is_expected.to be_disallowed(policy) }
          end
        end
      end
    end

    describe 'add_project_to_instance_security_dashboard' do
      let(:policy) { :add_project_to_instance_security_dashboard }

      context 'when user is auditor' do
        let(:current_user) { create(:user, :auditor) }

        it { is_expected.to be_allowed(policy) }
      end

      context 'when user is not auditor' do
        context 'with developer access' do
          let(:current_user) { developer }

          it { is_expected.to be_allowed(policy) }
        end

        context 'without developer access' do
          let(:current_user) { create(:user) }

          it { is_expected.to be_disallowed(policy) }
        end
      end
    end

    context 'visual review bot' do
      let(:current_user) { Users::Internal.visual_review_bot }

      it { expect_disallowed(:create_note) }
      it { expect_disallowed(:read_note) }
      it { expect_disallowed(:resolve_note) }
    end

    context 'when push_rules is not enabled by the current license' do
      before do
        stub_licensed_features(push_rules: false)
      end

      let(:current_user) { maintainer }

      it { is_expected.to be_disallowed(:change_push_rules) }
    end

    context 'when push_rules is enabled by the current license' do
      before do
        stub_licensed_features(push_rules: true)
      end

      let(:current_user) { maintainer }

      context 'when the user is an admin', :enable_admin_mode do
        let(:current_user) { admin }

        it { is_expected.to be_allowed(:change_push_rules) }
      end

      context 'when the user is a maintainer' do
        let(:current_user) { maintainer }

        it { is_expected.to be_allowed(:change_push_rules) }
      end

      context 'when the user is a developer' do
        let(:current_user) { developer }

        it { is_expected.to be_disallowed(:change_push_rules) }
      end
    end

    context 'commit_committer_check is not enabled by the current license' do
      before do
        stub_licensed_features(commit_committer_check: false)
      end

      let(:current_user) { maintainer }

      it { is_expected.not_to be_allowed(:change_commit_committer_check) }
      it { is_expected.not_to be_allowed(:read_commit_committer_check) }
    end

    context 'commit_committer_check is enabled by the current license' do
      before do
        stub_licensed_features(commit_committer_check: true)
      end

      context 'when the user is an admin', :enable_admin_mode do
        let(:current_user) { admin }

        it { is_expected.to be_allowed(:change_commit_committer_check) }
        it { is_expected.to be_allowed(:read_commit_committer_check) }
      end

      context 'the user is a maintainer' do
        let(:current_user) { maintainer }

        it { is_expected.to be_allowed(:change_commit_committer_check) }
        it { is_expected.to be_allowed(:read_commit_committer_check) }
      end

      context 'the user is a developer' do
        let(:current_user) { developer }

        it { is_expected.not_to be_allowed(:change_commit_committer_check) }
        it { is_expected.not_to be_allowed(:read_commit_committer_check) }
      end
    end

    context 'when commit_committer_name_check is not enabled by the current license' do
      before do
        stub_licensed_features(commit_committer_name_check: false)
      end

      let(:current_user) { maintainer }

      it { is_expected.to be_disallowed(:read_commit_committer_name_check) }
      it { is_expected.to be_disallowed(:change_commit_committer_name_check) }
    end

    context 'when commit_committer_name_check is enabled by the current license' do
      before do
        stub_licensed_features(commit_committer_name_check: true)
      end

      context 'when the user is an admin', :enable_admin_mode do
        let(:current_user) { admin }

        it { is_expected.to be_allowed(:read_commit_committer_name_check) }
        it { is_expected.to be_allowed(:change_commit_committer_name_check) }
      end

      context 'when the user is a maintainer' do
        let(:current_user) { maintainer }

        it { is_expected.to be_allowed(:read_commit_committer_name_check) }
        it { is_expected.to be_allowed(:change_commit_committer_name_check) }
      end

      context 'the user is a developer' do
        let(:current_user) { developer }

        it { is_expected.to be_disallowed(:read_commit_committer_name_check) }
        it { is_expected.to be_disallowed(:change_commit_committer_name_check) }
      end
    end

    context 'reject_unsigned_commits is not enabled by the current license' do
      before do
        stub_licensed_features(reject_unsigned_commits: false)
      end

      let(:current_user) { maintainer }

      it { is_expected.not_to be_allowed(:change_reject_unsigned_commits) }
      it { is_expected.not_to be_allowed(:read_reject_unsigned_commits) }
    end

    context 'reject_unsigned_commits is enabled by the current license' do
      before do
        stub_licensed_features(reject_unsigned_commits: true)
      end

      context 'when the user is an admin', :enable_admin_mode do
        let(:current_user) { admin }

        it { is_expected.to be_allowed(:change_reject_unsigned_commits) }
        it { is_expected.to be_allowed(:read_reject_unsigned_commits) }
      end

      context 'when the user is a maintainer' do
        let(:current_user) { maintainer }

        it { is_expected.to be_allowed(:change_reject_unsigned_commits) }
        it { is_expected.to be_allowed(:read_reject_unsigned_commits) }
      end

      context 'when the user is a developer' do
        let(:current_user) { developer }

        it { is_expected.not_to be_allowed(:change_reject_unsigned_commits) }
        it { is_expected.not_to be_allowed(:read_reject_unsigned_commits) }
      end
    end

    context 'when reject_non_dco_commits is not enabled by the current license' do
      before do
        stub_licensed_features(reject_non_dco_commits: false)
      end

      let(:current_user) { maintainer }

      it { is_expected.to be_disallowed(:read_reject_non_dco_commits) }
      it { is_expected.to be_disallowed(:change_reject_non_dco_commits) }
    end

    context 'when reject_non_dco_commits is enabled by the current license' do
      before do
        stub_licensed_features(reject_non_dco_commits: true)
      end

      context 'when the user is an admin', :enable_admin_mode do
        let(:current_user) { admin }

        it { is_expected.to be_allowed(:read_reject_non_dco_commits) }
        it { is_expected.to be_allowed(:change_reject_non_dco_commits) }
      end

      context 'when the user is a maintainer' do
        let(:current_user) { maintainer }

        it { is_expected.to be_allowed(:read_reject_non_dco_commits) }
        it { is_expected.to be_allowed(:change_reject_non_dco_commits) }
      end

      context 'when the user is a developer' do
        let(:current_user) { developer }

        it { is_expected.to be_disallowed(:read_reject_non_dco_commits) }
        it { is_expected.to be_disallowed(:change_reject_non_dco_commits) }
      end
    end

    context 'when dora4 analytics is available' do
      before do
        stub_licensed_features(dora4_analytics: true)
      end

      context 'when the user is a developer' do
        let(:current_user) { developer }

        it { is_expected.to be_allowed(:read_dora4_analytics) }
      end

      context 'when the user is an admin', :enable_admin_mode do
        let(:current_user) { admin }

        it { is_expected.to be_allowed(:read_dora4_analytics) }
      end
    end

    context 'when dora4 analytics is not available' do
      let(:current_user) { developer }

      before do
        stub_licensed_features(dora4_analytics: false)
      end

      it { is_expected.not_to be_allowed(:read_dora4_analytics) }
    end

    describe ':read_enterprise_ai_analytics' do
      let(:project) { private_project_in_group }
      let(:guest) { inherited_guest }
      let(:planner) { inherited_planner }
      let(:reporter) { inherited_reporter }

      context 'when on SAAS', :saas do
        let(:subscription_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: group) }

        it_behaves_like 'ai permission to', :read_enterprise_ai_analytics
      end

      context 'when on self-managed' do
        let(:subscription_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :self_managed) }

        it_behaves_like 'ai permission to', :read_enterprise_ai_analytics
      end

      context 'when Amazon Q is enabled' do
        using RSpec::Parameterized::TableSyntax

        where(:role, :amazon_q_enabled, :allow_policy) do
          :guest    | true  | be_disallowed(:read_enterprise_ai_analytics)
          :reporter | true  | be_allowed(:read_enterprise_ai_analytics)
          :reporter | false | be_disallowed(:read_enterprise_ai_analytics)
          :reporter | true  | be_allowed(:read_pro_ai_analytics)
          :reporter | false | be_disallowed(:read_pro_ai_analytics)
        end

        with_them do
          let(:current_user) { public_send(role) }

          before do
            allow(::Ai::AmazonQ).to receive(:enabled?).and_return(amazon_q_enabled)
          end

          it { is_expected.to allow_policy }
        end
      end
    end

    describe ':read_pro_ai_analytics' do
      let(:project) { private_project_in_group }
      let(:guest) { inherited_guest }
      let(:reporter) { inherited_reporter }

      context 'when on SAAS', :saas do
        context 'with pro subscription' do
          let(:subscription_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_pro, namespace: group) }

          it_behaves_like 'ai permission to', :read_pro_ai_analytics
        end

        context 'with enterprise subscription' do
          let(:subscription_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: group) }

          it_behaves_like 'ai permission to', :read_pro_ai_analytics
        end
      end

      context 'when on self-managed' do
        context 'with pro subscription' do
          let(:subscription_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_pro, :self_managed) }

          it_behaves_like 'ai permission to', :read_pro_ai_analytics
        end

        context 'with enterprise subscription' do
          let(:subscription_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :self_managed) }

          it_behaves_like 'ai permission to', :read_pro_ai_analytics
        end
      end
    end

    describe ':read_duo_usage_analytics' do
      let(:project) { private_project_in_group }
      let(:guest) { inherited_guest }
      let(:reporter) { inherited_reporter }

      context 'when on SAAS', :saas do
        context 'with core subscription' do
          let(:subscription_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_core, namespace: group) }

          it_behaves_like 'read_duo_usage_analytics permissions'
        end

        context 'with pro subscription' do
          let(:subscription_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_pro, namespace: group) }

          it_behaves_like 'read_duo_usage_analytics permissions'
        end

        context 'with enterprise subscription' do
          let(:subscription_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: group) }

          it_behaves_like 'read_duo_usage_analytics permissions'
        end

        context 'with amazon q subscription' do
          let(:subscription_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_amazon_q, namespace: group) }

          it_behaves_like 'read_duo_usage_analytics permissions'
        end
      end

      context 'when on self-managed' do
        context 'with self-hosted subscription' do
          let(:subscription_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_self_hosted, :self_managed) }

          it_behaves_like 'read_duo_usage_analytics permissions'
        end

        context 'with core subscription' do
          let(:subscription_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_core, :self_managed) }

          it_behaves_like 'read_duo_usage_analytics permissions'
        end

        context 'with pro subscription' do
          let(:subscription_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_pro, :self_managed) }

          it_behaves_like 'read_duo_usage_analytics permissions'
        end

        context 'with enterprise subscription' do
          let(:subscription_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :self_managed) }

          it_behaves_like 'read_duo_usage_analytics permissions'
        end

        context 'with amazon q subscription' do
          let(:subscription_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_amazon_q, :self_managed) }

          it_behaves_like 'read_duo_usage_analytics permissions'
        end
      end
    end

    describe ':read_code_review_analytics' do
      let(:policy) { :read_code_review_analytics }

      where(:role, :project_visibility, :allowed) do
        :guest      | 'public'   | true
        :planner    | 'public'   | true
        :reporter   | 'public'   | true
        :developer  | 'public'   | true
        :maintainer | 'public'   | true
        :owner      | 'public'   | true
        :admin      | 'public'   | true
        :guest      | 'internal' | true
        :planner    | 'internal' | true
        :reporter   | 'internal' | true
        :developer  | 'internal' | true
        :maintainer | 'internal' | true
        :owner      | 'internal' | true
        :admin      | 'internal' | true
        :guest      | 'private'  | false
        :planner    | 'private'  | false
        :reporter   | 'private'  | true
        :developer  | 'private'  | true
        :maintainer | 'private'  | true
        :owner      | 'private'  | true
        :admin      | 'private'  | true
      end

      with_them do
        let(:current_user) { public_send(role) }
        let(:project) { public_send(:"#{project_visibility}_project") }

        before do
          enable_admin_mode!(current_user) if role == :admin
        end

        it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }

        context 'with code review analytics is not available in license' do
          before do
            stub_licensed_features(code_review_analytics: false)
          end

          it { is_expected.to be_disallowed(:read_code_review_analytics) }
        end
      end
    end

    shared_examples 'merge request approval settings' do |admin_override_allowed = false|
      let(:project) { private_project }

      context 'with merge request approvers rules available in license' do
        where(:role, :setting, :admin_mode, :allowed) do
          :guest      | true  | nil    | false
          :planner    | true  | nil    | false
          :reporter   | true  | nil    | false
          :developer  | true  | nil    | false
          :maintainer | false | nil    | true
          :maintainer | true  | nil    | false
          :owner      | false | nil    | true
          :owner      | true  | nil    | false
          :admin      | false | false  | false
          :admin      | false | true   | true
          :admin      | true  | false  | false
          :admin      | true  | true   | admin_override_allowed
        end

        with_them do
          let(:current_user) { public_send(role) }

          before do
            stub_licensed_features(admin_merge_request_approvers_rules: true)
            stub_application_setting(app_setting => setting)
            enable_admin_mode!(current_user) if admin_mode
          end

          it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
        end
      end

      context 'with merge request approvers rules not available in license' do
        where(:role, :setting, :admin_mode, :allowed) do
          :guest      | true  | nil    | false
          :planner    | true  | nil    | false
          :reporter   | true  | nil    | false
          :developer  | true  | nil    | false
          :maintainer | false | nil    | true
          :maintainer | true  | nil    | true
          :owner      | false | nil    | true
          :owner      | true  | nil    | true
          :admin      | false | false  | false
          :admin      | false | true   | true
          :admin      | true  | false  | false
          :admin      | true  | true   | true
        end

        with_them do
          let(:current_user) { public_send(role) }

          before do
            stub_licensed_features(admin_merge_request_approvers_rules: false)
            stub_application_setting(app_setting => setting)
            enable_admin_mode!(current_user) if admin_mode
          end

          it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
        end
      end
    end

    describe ':admin_merge_request_approval_settings' do
      let(:project) { private_project }

      where(:role, :licensed, :allowed) do
        :guest      | true | false
        :planner    | true | false
        :reporter   | true  | false
        :developer  | true  | false
        :maintainer | false | false
        :maintainer | true  | true
        :owner      | false | false
        :owner      | true  | true
        :admin      | true  | true
        :admin      | false | false
      end

      with_them do
        let(:current_user) { public_send(role) }

        before do
          stub_licensed_features(merge_request_approvers: licensed)
          enable_admin_mode!(current_user) if role == :admin
        end

        it { is_expected.to(allowed ? be_allowed(:admin_merge_request_approval_settings) : be_disallowed(:admin_merge_request_approval_settings)) }
      end
    end

    describe ':modify_approvers_rules' do
      it_behaves_like 'merge request approval settings', true do
        let(:app_setting) { :disable_overriding_approvers_per_merge_request }
        let(:policy) { :modify_approvers_rules }
      end
    end

    describe ':modify_merge_request_author_setting' do
      it_behaves_like 'merge request approval settings' do
        let(:app_setting) { :prevent_merge_requests_author_approval }
        let(:policy) { :modify_merge_request_author_setting }
      end
    end

    describe ':modify_merge_request_committer_setting' do
      it_behaves_like 'merge request approval settings' do
        let(:app_setting) { :prevent_merge_requests_committers_approval }
        let(:policy) { :modify_merge_request_committer_setting }
      end
    end

    it_behaves_like 'resource with requirement permissions' do
      let(:resource) { project }
    end

    describe 'Quality Management test case' do
      let(:policy) { :create_test_case }

      where(:role, :admin_mode, :allowed) do
        :guest      | nil   | false
        :planner    | nil   | true
        :reporter   | nil   | true
        :developer  | nil   | true
        :maintainer | nil   | true
        :owner      | nil   | true
        :admin      | false | false
        :admin      | true  | true
      end

      before do
        stub_licensed_features(quality_management: true)
        enable_admin_mode!(current_user) if admin_mode
      end

      with_them do
        let(:current_user) { public_send(role) }

        it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }

        context 'with unavailable license' do
          before do
            stub_licensed_features(quality_management: false)
          end

          it { is_expected.to(be_disallowed(policy)) }
        end
      end
    end

    shared_examples_for 'prevents CI cancellation ability' do
      context 'when feature is enabled' do
        where(:restricted_role, :actual_role, :allowed) do
          :developer  | :planner    | false
          :developer  | :guest      | false
          :developer  | :reporter   | false
          :developer  | :developer  | true
          :developer  | :maintainer | true
          :developer  | :owner      | true
          :maintainer | :planner    | false
          :maintainer | :guest      | false
          :maintainer | :reporter   | false
          :maintainer | :developer  | false
          :maintainer | :maintainer | true
          :maintainer | :owner      | true
          :no_one     | :planner    | false
          :no_one     | :guest      | false
          :no_one     | :reporter   | false
          :no_one     | :developer  | false
          :no_one     | :maintainer | false
          :no_one     | :owner      | false
        end

        with_them do
          let(:current_user) { public_send(actual_role) }

          before do
            stub_licensed_features(ci_pipeline_cancellation_restrictions: true)
            project.update!(restrict_pipeline_cancellation_role: restricted_role)
          end

          it { is_expected.to(allowed ? be_allowed(ability) : be_disallowed(ability)) }
        end
      end
    end

    describe 'prevents cancel_pipeline when CI cancllation restricted' do
      let(:ability) { :cancel_pipeline }

      it_behaves_like 'prevents CI cancellation ability'
    end

    describe 'prevents cancel_build when CI cancllation restricted' do
      let(:ability) { :cancel_build }

      it_behaves_like 'prevents CI cancellation ability'
    end

    describe 'project level compliance features' do
      shared_examples 'project level compliance feature' do |feature, permission|
        context 'when enabled' do
          before do
            stub_licensed_features({ feature => true })
          end

          context 'when project is in group' do
            let(:project) { public_project_in_group }

            context 'when user is eligible for access' do
              where(role: %w[owner auditor])

              with_them do
                let(:current_user) { public_send(role) }

                it { is_expected.to be_allowed(permission) }
              end
            end

            context 'allows admin', :enable_admin_mode do
              let(:current_user) { admin }

              it { is_expected.to be_allowed(permission) }
            end
          end

          context 'when project is in personal namespace' do
            let(:current_user) { owner }
            let(:project) { public_project }

            it { is_expected.to be_disallowed(permission) }
          end
        end

        context 'when disabled' do
          before do
            stub_licensed_features({ feature => false })
          end

          context 'when user is eligible for access' do
            where(role: %w[owner auditor])

            with_them do
              let(:current_user) { public_send(role) }

              it { is_expected.to be_disallowed(permission) }
            end
          end

          context 'disallows admin', :enable_admin_mode do
            let(:current_user) { admin }

            it { is_expected.to be_disallowed(permission) }
          end
        end
      end

      describe 'project level compliance dashboard' do
        it_behaves_like 'project level compliance feature', :project_level_compliance_dashboard, :read_compliance_dashboard
      end

      describe 'project level compliance adherence report' do
        it_behaves_like 'project level compliance feature', :project_level_compliance_adherence_report, :read_compliance_adherence_report
      end

      describe 'project level compliance violations report' do
        it_behaves_like 'project level compliance feature', :project_level_compliance_violations_report, :read_compliance_violations_report
      end
    end

    describe 'project level admin_compliance_framework check delegates to group', :eager_load do
      let(:project)  { public_project_in_group }
      let(:policy) { :admin_compliance_framework }

      where(:role, :feature_enabled, :admin_mode, :allowed) do
        :guest      | false | nil   | false
        :guest      | true  | nil   | false
        :planner    | false | nil   | false
        :planner    | true  | nil   | false
        :reporter   | false | nil   | false
        :reporter   | true  | nil   | false
        :developer  | false | nil   | false
        :maintainer | false | nil   | false
        :maintainer | true  | nil   | false
        :owner      | false | nil   | false
        :owner      | true  | nil   | true
        :admin      | false | false | false
        :admin      | false | true  | false
        :admin      | true  | false | false
        :admin      | true  | true  | true
      end

      with_them do
        let(:current_user) { role == :admin ? admin : owner }

        before do
          project.group.public_send("add_#{role}", current_user) unless role == :admin
          stub_licensed_features(compliance_framework: feature_enabled, custom_compliance_frameworks: feature_enabled)
          enable_admin_mode!(current_user) if admin_mode
        end

        it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
      end
    end

    describe 'Incident Management on-call schedules' do
      let(:current_user) { public_send(role) }
      let(:admin_mode) { false }

      before do
        enable_admin_mode!(current_user) if admin_mode
        stub_licensed_features(oncall_schedules: true)
      end

      context ':read_incident_management_oncall_schedule' do
        let(:policy) { :read_incident_management_oncall_schedule }

        where(:role, :admin_mode, :allowed) do
          :guest      | nil   | false
          :planner    | nil   | false
          :reporter   | nil   | true
          :developer  | nil   | true
          :maintainer | nil   | true
          :owner      | nil   | true
          :admin      | false | false
          :admin      | true  | true
          :auditor    | false | true
        end

        with_them do
          it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }

          context 'with unavailable license' do
            before do
              stub_licensed_features(oncall_schedules: false)
            end

            it { is_expected.to(be_disallowed(policy)) }
          end
        end

        it_behaves_like 'monitor feature visibility', allow_lowest_role: :reporter
      end

      context ':admin_incident_management_oncall_schedule' do
        let(:policy) { :admin_incident_management_oncall_schedule }

        where(:role, :admin_mode, :allowed) do
          :guest      | nil   | false
          :planner    | nil   | false
          :reporter   | nil   | false
          :developer  | nil   | false
          :maintainer | nil   | true
          :owner      | nil   | true
          :admin      | false | false
          :admin      | true  | true
          :auditor    | false | false
        end

        with_them do
          it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }

          context 'with unavailable license' do
            before do
              stub_licensed_features(oncall_schedules: false)
            end

            it { is_expected.to(be_disallowed(policy)) }
          end
        end

        it_behaves_like 'monitor feature visibility', allow_lowest_role: :maintainer
      end
    end

    describe 'Escalation Policies' do
      let(:current_user) { public_send(role) }
      let(:admin_mode) { false }

      before do
        enable_admin_mode!(current_user) if admin_mode
        allow(::Gitlab::IncidentManagement).to receive(:escalation_policies_available?).with(project).and_return(true)
      end

      context ':read_incident_management_escalation_policy' do
        let(:policy) { :read_incident_management_escalation_policy }

        where(:role, :admin_mode, :allowed) do
          :guest      | nil   | false
          :planner    | nil   | false
          :reporter   | nil   | true
          :developer  | nil   | true
          :maintainer | nil   | true
          :owner      | nil   | true
          :admin      | false | false
          :admin      | true  | true
          :auditor    | false | true
        end

        with_them do
          it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }

          context 'with unavailable escalation policies' do
            before do
              allow(::Gitlab::IncidentManagement).to receive(:escalation_policies_available?).with(project).and_return(false)
            end

            it { is_expected.to(be_disallowed(policy)) }
          end
        end

        it_behaves_like 'monitor feature visibility', allow_lowest_role: :reporter
      end

      context ':admin_incident_management_escalation_policy' do
        let(:policy) { :admin_incident_management_escalation_policy }

        where(:role, :admin_mode, :allowed) do
          :guest      | nil   | false
          :planner    | nil   | false
          :reporter   | nil   | false
          :developer  | nil   | false
          :maintainer | nil   | true
          :owner      | nil   | true
          :admin      | false | false
          :admin      | true  | true
          :auditor    | false | false
        end

        with_them do
          it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }

          context 'with unavailable escalation policies' do
            before do
              allow(::Gitlab::IncidentManagement).to receive(:escalation_policies_available?).with(project).and_return(false)
            end

            it { is_expected.to(be_disallowed(policy)) }
          end
        end

        it_behaves_like 'monitor feature visibility', allow_lowest_role: :maintainer
      end
    end

    context 'when project is read only on the namespace' do
      let(:project) { public_project_in_group }
      let(:current_user) { maintainer }
      let(:abilities) do
        described_class.readonly_features.flat_map do |feature|
          [
            :"create_#{feature}",
            :"update_#{feature}",
            :"admin_#{feature}"
          ]
        end + described_class.readonly_abilities
      end

      before do
        allow(project.root_namespace).to receive(:read_only?).and_return(read_only)
        allow(project).to receive(:design_management_enabled?).and_return(true)
        stub_licensed_features(security_dashboard: true, license_scanning: true, quality_management: true)
      end

      context 'when the group is read only' do
        let(:read_only) { true }

        it { is_expected.to(be_disallowed(*abilities)) }
      end

      context 'when the group is not read only' do
        let(:read_only) { false }

        # These are abilities that are not explicitly allowed by policies because most of them are not
        # real abilities.
        let(:abilities_not_currently_enabled) do
          %i[create_merge_request create_issue_board_list create_issue_board update_issue_board
             update_issue_board_list create_label update_label create_milestone
             update_milestone update_wiki update_design admin_design update_note
             update_pipeline_schedule admin_pipeline_schedule create_trigger update_trigger
             admin_trigger create_pages admin_release request_access create_board update_board
             create_issue_link update_issue_link create_approvers admin_approvers
             admin_vulnerability_feedback create_feature_flags_client
             update_feature_flags_client update_iteration update_vulnerability create_vulnerability]
        end

        it { is_expected.to(be_allowed(*(abilities - abilities_not_currently_enabled))) }
      end
    end

    context 'project access tokens' do
      context 'GitLab.com Core resource access tokens', :saas do
        before do
          stub_ee_application_setting(should_check_namespace_plan: true)
        end

        context 'with admin access' do
          let(:current_user) { owner }

          before do
            project.add_owner(owner)
          end

          context 'when project belongs to a group' do
            let_it_be(:group) { create(:group) }
            let_it_be(:project) { create(:project, group: group) }

            it { is_expected.not_to be_allowed(:create_resource_access_tokens) }
            it { is_expected.to be_allowed(:read_resource_access_tokens) }
            it { is_expected.to be_allowed(:destroy_resource_access_tokens) }
          end

          context 'when project belongs to personal namespace' do
            it { is_expected.to be_allowed(:create_resource_access_tokens) }
            it { is_expected.to be_allowed(:read_resource_access_tokens) }
            it { is_expected.to be_allowed(:destroy_resource_access_tokens) }
          end
        end

        context 'with non admin access' do
          let(:current_user) { developer }

          before do
            project.add_developer(developer)
          end

          context 'when project belongs to a group' do
            let_it_be(:group) { create(:group) }
            let_it_be(:project) { create(:project, group: group) }

            it { is_expected.not_to be_allowed(:create_resource_access_tokens) }
            it { is_expected.not_to be_allowed(:read_resource_access_tokens) }
            it { is_expected.not_to be_allowed(:destroy_resource_access_tokens) }
          end

          context 'when project belongs to personal namespace' do
            it { is_expected.not_to be_allowed(:create_resource_access_tokens) }
            it { is_expected.not_to be_allowed(:read_resource_access_tokens) }
            it { is_expected.not_to be_allowed(:destroy_resource_access_tokens) }
          end
        end
      end

      context 'on GitLab.com paid', :saas do
        let_it_be(:group) { create(:group_with_plan, plan: :bronze_plan) }
        let_it_be(:project) { create(:project, group: group) }

        context 'with maintainer access' do
          let(:current_user) { maintainer }

          before do
            project.add_maintainer(maintainer)
          end

          it_behaves_like 'GitLab.com Paid plan resource access tokens'

          context 'create resource access tokens' do
            it { is_expected.to be_allowed(:create_resource_access_tokens) }

            context 'with a personal namespace project' do
              let(:namespace) { create(:namespace_with_plan, plan: :bronze_plan) }
              let(:project) { create(:project, namespace: namespace) }

              it { is_expected.to be_allowed(:create_resource_access_tokens) }
            end

            context 'when resource access token creation is not allowed' do
              before do
                group.namespace_settings.update_column(:resource_access_token_creation_allowed, false)
              end

              it { is_expected.not_to be_allowed(:create_resource_access_tokens) }
            end

            context 'when parent group has resource access token creation disabled' do
              let(:resource_access_token_creation_allowed) { false }
              let(:ns_for_parent) { create(:namespace_settings, resource_access_token_creation_allowed: resource_access_token_creation_allowed) }
              let(:parent) { create(:group_with_plan, plan: :bronze_plan, namespace_settings: ns_for_parent) }
              let(:group) { create(:group, parent: parent) }
              let(:project) { create(:project, group: group) }

              context 'cannot create resource access tokens' do
                it { is_expected.not_to be_allowed(:create_resource_access_tokens) }
              end
            end
          end

          context 'read resource access tokens' do
            it { is_expected.to be_allowed(:read_resource_access_tokens) }
          end

          context 'destroy resource access tokens' do
            it { is_expected.to be_allowed(:destroy_resource_access_tokens) }
          end
        end

        context 'with developer access' do
          let(:current_user) { developer }

          before do
            project.add_developer(developer)
          end

          context 'create resource access tokens' do
            it { is_expected.not_to be_allowed(:create_resource_access_tokens) }
          end

          context 'read resource access tokens' do
            it { is_expected.not_to be_allowed(:read_resource_access_tokens) }
          end

          context 'destroy resource access tokens' do
            it { is_expected.not_to be_allowed(:destroy_resource_access_tokens) }
          end
        end

        context 'with auditor access' do
          let(:current_user) { auditor }

          context 'read resource access tokens' do
            it { is_expected.to be_allowed(:read_resource_access_tokens) }
          end

          context 'cannot create resource access tokens' do
            it { is_expected.not_to be_allowed(:create_resource_access_tokens) }
          end

          context 'cannot destroy resource access tokens' do
            it { is_expected.not_to be_allowed(:destroy_resource_access_tokens) }
          end
        end
      end
    end

    describe 'read_analytics' do
      context 'with various analytics features' do
        let_it_be(:project_with_analytics_disabled) { create(:project, :analytics_disabled) }
        let_it_be(:project_with_analytics_private) { create(:project, :analytics_private) }
        let_it_be(:project_with_analytics_enabled) { create(:project, :analytics_enabled) }

        let(:all_read_analytics_permissions) do
          %i[
            read_project_merge_request_analytics
          read_code_review_analytics
          read_cycle_analytics
          read_issue_analytics
          ]
        end

        before do
          stub_licensed_features(issues_analytics: true, code_review_analytics: true, project_merge_request_analytics: true, cycle_analytics_for_projects: true)

          project_with_analytics_disabled.add_developer(developer)
          project_with_analytics_private.add_developer(developer)
          project_with_analytics_enabled.add_developer(developer)
        end

        context 'when analytics is disabled for the project' do
          let(:project) { project_with_analytics_disabled }

          %w[guest planner developer admin auditor].each do |role|
            context "for #{role} user" do
              let(:current_user) { send(role) }

              it { is_expected.to be_disallowed(*all_read_analytics_permissions) }
            end
          end
        end

        context 'when analytics is private for the project' do
          let(:project) { project_with_analytics_private }

          %w[guest planner].each do |role|
            context "for #{role} user" do
              let(:current_user) { send(role) }

              it { is_expected.to be_disallowed(*all_read_analytics_permissions) }
            end
          end

          context 'for developer' do
            let(:current_user) { developer }

            it { is_expected.to be_allowed(*all_read_analytics_permissions) }
          end

          context 'for admin', :enable_admin_mode do
            let(:current_user) { admin }

            it { is_expected.to be_allowed(*all_read_analytics_permissions) }
          end

          context 'for auditor' do
            let(:current_user) { auditor }

            it { is_expected.to be_allowed(*all_read_analytics_permissions) }
          end
        end

        context 'when analytics is enabled for the project' do
          let(:project) { project_with_analytics_enabled }

          %w[guest planner].each do |role|
            context "for #{role} user" do
              let(:current_user) { send(role) }

              it { is_expected.to be_disallowed(:read_project_merge_request_analytics) }
              it { is_expected.to be_disallowed(:read_code_review_analytics) }
              it { is_expected.to be_disallowed(:read_cycle_analytics) }
              it { is_expected.to be_allowed(:read_issue_analytics) }
            end
          end

          context 'for developer' do
            let(:current_user) { developer }

            it { is_expected.to be_allowed(*all_read_analytics_permissions) }
          end

          context 'for admin', :enable_admin_mode do
            let(:current_user) { admin }

            it { is_expected.to be_allowed(*all_read_analytics_permissions) }
          end

          context 'for auditor' do
            let(:current_user) { auditor }

            it { is_expected.to be_allowed(*all_read_analytics_permissions) }
          end
        end
      end
    end

    describe ':build_read_project' do
      let(:policy) { :build_read_project }

      where(:role, :project_visibility, :allowed) do
        :guest      | 'public'   | true
        :planner    | 'public'   | true
        :reporter   | 'public'   | true
        :developer  | 'public'   | true
        :maintainer | 'public'   | true
        :owner      | 'public'   | true
        :admin      | 'public'   | true
        :guest      | 'internal' | true
        :planner    | 'internal' | true
        :reporter   | 'internal' | true
        :developer  | 'internal' | true
        :maintainer | 'internal' | true
        :owner      | 'internal' | true
        :admin      | 'internal' | true
        :guest      | 'private'  | false
        :planner    | 'private'  | false
        :reporter   | 'private'  | true
        :developer  | 'private'  | true
        :maintainer | 'private'  | true
        :owner      | 'private'  | true
        :admin      | 'private'  | false
      end

      with_them do
        let(:current_user) { public_send(role) }

        before do
          project.update_column(:visibility_level, Gitlab::VisibilityLevel.level_value(project_visibility))
        end

        it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
      end
    end

    describe 'pending member permissions' do
      let_it_be(:current_user) { create(:user) }
      let_it_be(:group) { create(:group, :public) }

      context 'with a pending membership in a private project' do
        let_it_be(:project) { create(:project, :private, public_builds: false) }

        where(:role) do
          Gitlab::Access.sym_options.keys.map(&:to_sym)
        end

        with_them do
          it 'a pending member has permissions to the project as if the user is not a member' do
            create(:project_member, :awaiting, role, source: project, user: current_user)

            expect_private_project_permissions_as_if_non_member
          end
        end
      end

      context 'with a group invited to a project' do
        let_it_be(:project) { create(:project, :private, public_builds: false) }

        before_all do
          create(:project_group_link, project: project, group: group)
        end

        where(:role) do
          Gitlab::Access.sym_options_with_owner.keys.map(&:to_sym)
        end

        with_them do
          it 'a pending member in the group has permissions to the project as if the user is not a member' do
            create(:group_member, :awaiting, role, source: group, user: current_user)

            expect_private_project_permissions_as_if_non_member
          end
        end
      end

      context 'with a group invited to another group' do
        let_it_be(:other_group) { create(:group, :public) }
        let_it_be(:project) { create(:project, :private, public_builds: false, namespace: other_group) }

        before_all do
          create(:group_group_link, shared_with_group: group, shared_group: other_group)
        end

        where(:role) do
          Gitlab::Access.sym_options_with_owner.keys.map(&:to_sym)
        end

        with_them do
          it "a pending member in the group has permissions to the other group's project as if the user is not a member" do
            create(:group_member, :awaiting, role, source: group, user: current_user)

            expect_private_project_permissions_as_if_non_member
          end
        end
      end

      context 'with a subgroup' do
        let_it_be(:subgroup) { create(:group, :private, parent: group) }
        let_it_be(:project) { create(:project, :private, public_builds: false, namespace: subgroup) }

        where(:role) do
          Gitlab::Access.sym_options_with_owner.keys.map(&:to_sym)
        end

        with_them do
          it 'a pending member in the group has permissions to the subgroup project as if the user is not a member' do
            create(:group_member, :awaiting, role, source: group, user: current_user)

            expect_private_project_permissions_as_if_non_member
          end
        end
      end

      def expect_private_project_permissions_as_if_non_member
        expect_disallowed(*guest_permissions)
        expect_disallowed(*reporter_permissions)
        expect_disallowed(*team_member_reporter_permissions)
        expect_disallowed(*developer_permissions)
        expect_disallowed(*maintainer_permissions)
        expect_disallowed(*owner_permissions)
      end

      describe ':read_approvers' do
        let(:policy) { :read_approvers }

        where(:role, :allowed) do
          :guest      | false
          :planner    | false
          :reporter   | false
          :developer  | false
          :maintainer | true
          :auditor    | true
          :owner      | true
          :admin      | true
        end

        with_them do
          let(:current_user) { public_send(role) }

          before do
            enable_admin_mode!(current_user) if role == :admin
          end

          it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
        end
      end
    end

    context 'for membership locking' do
      let(:current_user) { owner }

      context 'for a personal project' do
        it { is_expected.to be_allowed(:import_project_members_from_another_project) }
        it { is_expected.to be_allowed(:invite_member) }
      end

      context 'for a project in a group' do
        let(:project) { create(:project, group: create(:group)) }

        context 'when the project has locked their membership' do
          context 'via the parent group' do
            before do
              project.group.update!(membership_lock: true)
            end

            it { is_expected.to be_disallowed(:import_project_members_from_another_project) }
            it { is_expected.to be_disallowed(:invite_member) }
          end

          context 'via LDAP' do
            before do
              stub_application_setting(lock_memberships_to_ldap: true)
            end

            it { is_expected.to be_disallowed(:import_project_members_from_another_project) }
            it { is_expected.to be_disallowed(:invite_member) }
          end

          context 'via SAML' do
            before do
              stub_application_setting(lock_memberships_to_saml: true)
            end

            it { is_expected.to be_disallowed(:import_project_members_from_another_project) }
            it { is_expected.to be_disallowed(:invite_member) }
          end
        end
      end
    end

    describe 'inviting a group' do
      let_it_be_with_reload(:current_user) { developer }
      let_it_be_with_reload(:project) { public_project }

      let_it_be(:banned_group) { create(:group) }
      let_it_be(:banned_subgroup) { create(:group, parent: banned_group) }

      before do
        stub_licensed_features(unique_project_download_limit: true)
        create(:namespace_ban, user: current_user, namespace: banned_group)
      end

      it { is_expected.to be_allowed(:read_project) }

      context 'when the user is banned from the invited group' do
        before do
          create(:project_group_link, project: project, group: banned_group)
        end

        it { is_expected.to be_disallowed(:read_project) }
      end

      context 'when the user is banned from the invited subgroup' do
        before do
          create(:project_group_link, project: project, group: banned_subgroup)
        end

        it { is_expected.to be_disallowed(:read_project) }
      end
    end

    describe 'user banned from namespace' do
      let_it_be_with_reload(:current_user) { create(:user) }

      let_it_be(:group) { create(:group, :private) }
      let_it_be(:project) { create(:project, :private, public_builds: false, group: group) }

      before do
        stub_licensed_features(unique_project_download_limit: true)
        project.add_developer(current_user)
      end

      context 'when user is not banned' do
        it { is_expected.to be_allowed(:read_project) }
      end

      context 'when user is banned' do
        before do
          create(:namespace_ban, user: current_user, namespace: group.root_ancestor)
        end

        it { is_expected.to be_disallowed(*described_class.own_ability_map.map.keys) }

        context 'as an owner of the project' do
          before do
            project.add_owner(current_user)
          end

          it { is_expected.to be_disallowed(*described_class.own_ability_map.map.keys) }
        end

        context 'when project is inside subgroup' do
          let_it_be(:subgroup) { create(:group, :private, parent: group) }
          let_it_be(:project) { create(:project, :private, public_builds: false, group: subgroup) }

          it { is_expected.to be_disallowed(*described_class.own_ability_map.map.keys) }
        end

        context 'as an admin' do
          let_it_be(:current_user) { admin }

          context 'when admin mode is enabled', :enable_admin_mode do
            it { is_expected.to be_allowed(:read_project) }
          end
        end

        context 'when project is public' do
          let_it_be(:group) { create(:group, :public) }
          let_it_be(:project) { create(:project, :public, public_builds: false, group: group) }

          it { is_expected.to be_disallowed(:read_project) }
        end

        context 'when licensed feature unique_project_download_limit is not available' do
          before do
            stub_licensed_features(unique_project_download_limit: false)
          end

          it { is_expected.to be_allowed(:read_project) }
        end
      end
    end

    describe 'create_objective' do
      let(:okr_policies) { [:create_objective, :create_key_result] }

      where(:role, :allowed) do
        :guest      | true
        :planner    | true
        :reporter   | true
        :developer  | true
        :maintainer | true
        :auditor    | false
        :owner      | true
        :admin      | true
      end

      with_them do
        let(:current_user) { public_send(role) }

        before do
          enable_admin_mode!(current_user) if role == :admin
          stub_licensed_features(okrs: true)
        end

        context 'when okrs_mvc feature flag is enabled' do
          it { is_expected.to(allowed ? be_allowed(*okr_policies) : be_disallowed(*okr_policies)) }
        end

        context 'when okrs_mvc feature flag is disabled' do
          before do
            stub_feature_flags(okrs_mvc: false)
          end

          it { is_expected.to be_disallowed(*okr_policies) }
        end

        context 'when okrs license feature is not available' do
          before do
            stub_licensed_features(okrs: false)
          end

          it { is_expected.to be_disallowed(*okr_policies) }
        end
      end
    end

    describe 'read_member_role' do
      let_it_be_with_reload(:project) { private_project_in_group }
      let_it_be_with_reload(:current_user) { create(:user) }

      let(:permission) { :read_member_role }

      where(:role, :allowed) do
        :guest      | true
        :planner    | true
        :reporter   | true
        :developer  | true
        :maintainer | true
        :auditor    | false
        :owner      | true
        :admin      | true
      end

      with_them do
        before do
          if role == :admin
            current_user.update!(admin: true)
          elsif role == :auditor
            current_user.update!(auditor: true)
          else
            create(:project_member, role, source: project, user: current_user)
          end

          enable_admin_mode!(current_user) if role == :admin
        end

        context 'when custom_roles feature is enabled' do
          before do
            stub_licensed_features(custom_roles: true)
          end

          it do
            is_expected.to(allowed ? be_allowed(permission) : be_disallowed(permission))
          end
        end

        context 'when custom_roles feature is disabled' do
          before do
            stub_licensed_features(custom_roles: false)
          end

          it { is_expected.to be_disallowed(permission) }
        end
      end
    end

    context 'hidden projects' do
      let(:project) { create(:project, :repository, hidden: true) }
      let(:current_user) { create(:user) }

      before do
        project.add_owner(current_user)
      end

      it { is_expected.to be_disallowed(:download_code) }
      it { is_expected.to be_disallowed(:build_download_code) }
    end

    context 'custom role' do
      let_it_be(:guest) { create(:user) }
      let_it_be(:project) { private_project_in_group }
      let_it_be(:group_member_guest) do
        create(
          :group_member,
          user: guest,
          source: project.group,
          access_level: Gitlab::Access::GUEST
        )
      end

      let_it_be(:project_member_guest) do
        create(
          :project_member,
          :guest,
          user: guest,
          project: project,
          access_level: Gitlab::Access::GUEST
        )
      end

      let(:member_role_abilities) { {} }
      let(:allowed_abilities) { [] }
      let(:disallowed_abilities) { [] }
      let(:current_user) { guest }
      let(:licensed_features) { {} }

      subject { described_class.new(current_user, project) }

      before do
        stub_licensed_features(custom_roles: true)
      end

      def create_member_role(member, abilities = member_role_abilities)
        params = abilities.merge(namespace: project.group)

        create(:member_role, :guest, params).tap do |role|
          role.members << member
        end
      end

      shared_examples 'custom roles abilities' do
        context 'with custom_roles license disabled' do
          before do
            create_member_role(group_member_guest)

            stub_licensed_features(licensed_features.merge(custom_roles: false))
          end

          it { expect_disallowed(*allowed_abilities) }
        end

        context 'with custom_roles license enabled' do
          before do
            stub_licensed_features(licensed_features.merge(custom_roles: true))
          end

          context 'custom role for parent group' do
            context 'when a role enables the abilities' do
              before do
                create_member_role(group_member_guest)
              end

              it { expect_allowed(*allowed_abilities) }
              it { expect_disallowed(*disallowed_abilities) }
            end

            context 'when a role does not enable the abilities' do
              it { expect_disallowed(*allowed_abilities) }
            end
          end

          context 'custom role on project membership' do
            context 'when a role enables the abilities' do
              before do
                create_member_role(project_member_guest)
              end

              it { expect_allowed(*allowed_abilities) }
              it { expect_disallowed(*disallowed_abilities) }
            end

            context 'when a role does not enable the abilities' do
              it { expect_disallowed(*allowed_abilities) }
            end
          end
        end
      end

      context 'for a member role with read_code true' do
        let(:member_role_abilities) { { read_code: true } }
        let(:allowed_abilities) { [:read_code] }

        it_behaves_like 'custom roles abilities'

        context 'when repository access level is set as disabled' do
          before do
            project.project_feature.update_column(:repository_access_level, ProjectFeature::DISABLED)

            create_member_role(project_member_guest)
          end

          after do
            project.project_feature.update_column(:repository_access_level, ProjectFeature::ENABLED)
          end

          it { expect_disallowed(:read_code) }
        end
      end

      context 'for a member role with admin_runners true' do
        let(:member_role_abilities) { { admin_runners: true } }
        let(:allowed_abilities) do
          [
            :admin_runner,
            :create_runner,
            :read_runner
          ]
        end

        it_behaves_like 'custom roles abilities'
      end

      context 'for a member role with read_vulnerability true' do
        let(:member_role_abilities) { { read_vulnerability: true } }
        let(:licensed_features) { { security_dashboard: true } }
        let(:allowed_abilities) do
          [
            :access_security_and_compliance,
            :create_vulnerability_export,
            :create_vulnerability_archive_export,
            :read_security_resource,
            :read_vulnerability,
            :read_vulnerability_feedback,
            :read_vulnerability_scanner
          ]
        end

        it_behaves_like 'custom roles abilities'

        it 'does not enable to admin_vulnerability' do
          expect(subject).to be_disallowed(:admin_vulnerability)
        end
      end

      context 'for a member role with admin_terraform_state true' do
        let(:member_role_abilities) { { admin_terraform_state: true } }
        let(:allowed_abilities) { [:read_terraform_state, :admin_terraform_state] }

        it_behaves_like 'custom roles abilities'
      end

      context 'for a member role with admin_vulnerability true' do
        let(:member_role_abilities) { { read_vulnerability: true, admin_vulnerability: true } }
        let(:licensed_features) { { security_dashboard: true } }
        let(:allowed_abilities) do
          [
            :admin_vulnerability,
            :create_vulnerability_feedback,
            :destroy_vulnerability_feedback,
            :read_vulnerability,
            :read_vulnerability_feedback,
            :update_vulnerability_feedback,
            :create_vulnerability_state_transition
          ]
        end

        it_behaves_like 'custom roles abilities'
      end

      context 'for a member role with read_dependency true' do
        let(:member_role_abilities) { { read_dependency: true } }
        let(:allowed_abilities) { [:access_security_and_compliance, :read_dependency] }
        let(:licensed_features) { { dependency_scanning: true } }

        it_behaves_like 'custom roles abilities'
      end

      context 'for a member role with admin_merge_request true' do
        let(:member_role_abilities) { { admin_merge_request: true } }
        let(:allowed_abilities) { [:admin_merge_request] }

        it_behaves_like 'custom roles abilities'

        context 'when the merge requests access level is set as private' do
          before do
            project.project_feature.update_column(:merge_requests_access_level, ProjectFeature::PRIVATE)
          end

          it_behaves_like 'custom roles abilities'
        end

        context 'when the merge requests access level is set as disabled' do
          before do
            project.project_feature.update_column(:merge_requests_access_level, ProjectFeature::DISABLED)
          end

          it { is_expected.to be_disallowed(:read_merge_request, :admin_merge_request, :download_code) }
        end
      end

      context 'for a member role with manage_project_access_tokens true' do
        let(:member_role_abilities) { { manage_project_access_tokens: true } }
        let(:allowed_abilities) { [:manage_resource_access_tokens] }

        it_behaves_like 'custom roles abilities'
      end

      context 'for a member role with archive_project true' do
        let(:member_role_abilities) { { archive_project: true } }
        let(:allowed_abilities) { [:archive_project, :view_edit_page] }

        it_behaves_like 'custom roles abilities'
      end

      context 'for a member role with `remove_project` true' do
        let(:member_role_abilities) { { remove_project: true } }
        let(:allowed_abilities) { [:remove_project, :view_edit_page] }

        it_behaves_like 'custom roles abilities'
      end

      context 'for a member role with `manage_security_policy_link` true' do
        let(:member_role_abilities) { { manage_security_policy_link: true } }
        let(:licensed_features) { { security_orchestration_policies: true } }
        let(:allowed_abilities) do
          [:read_security_orchestration_policies, :update_security_orchestration_policy_project,
           :access_security_and_compliance]
        end

        let(:disallowed_abilities) do
          [:modify_security_policy]
        end

        it_behaves_like 'custom roles abilities'
      end

      context 'when a user is assigned to custom roles in both group and project' do
        before do
          stub_licensed_features(custom_roles: true, dependency_scanning: true)

          create_member_role(group_member_guest, { read_dependency: true })
          create_member_role(project_member_guest, { read_code: true })
        end

        it { is_expected.to be_allowed(:read_dependency) }
        it { is_expected.to be_allowed(:read_code) }
      end

      context 'for a custom role with the `admin_cicd_variables` ability' do
        let(:member_role_abilities) { { admin_cicd_variables: true } }
        let(:allowed_abilities) { [:admin_cicd_variables] }

        it_behaves_like 'custom roles abilities'
      end

      context 'for a custom role with the `admin_protected_environments` ability' do
        let(:member_role_abilities) { { admin_protected_environments: true } }
        let(:allowed_abilities) { [:admin_protected_environments] }

        it_behaves_like 'custom roles abilities'
      end

      context 'for a custom role with the `admin_push_rules` ability' do
        let(:member_role_abilities) { { admin_push_rules: true } }
        let(:allowed_abilities) { [:admin_push_rules] }

        it_behaves_like 'custom roles abilities'

        context 'when push rules feature is enabled' do
          before do
            stub_licensed_features(
              custom_roles: true,
              push_rules: true,
              commit_committer_check: true,
              commit_committer_name_check: true,
              reject_unsigned_commits: true,
              reject_non_dco_commits: true
            )

            create_member_role(group_member_guest)
          end

          it do
            expect_allowed(
              :change_push_rules,
              :read_commit_committer_check,
              :change_commit_committer_check,
              :change_commit_committer_name_check,
              :read_reject_unsigned_commits,
              :change_reject_unsigned_commits,
              :change_reject_non_dco_commits
            )
          end
        end
      end

      context 'for a custom role with the `admin_compliance_framework` ability' do
        let(:licensed_features) do
          {
            compliance_framework: true,
            project_level_compliance_dashboard: true,
            project_level_compliance_adherence_report: true,
            project_level_compliance_violations_report: true
          }
        end

        let(:member_role_abilities) { { read_compliance_dashboard: true, admin_compliance_framework: true } }

        let(:allowed_abilities) do
          [
            :admin_compliance_framework,
            :read_compliance_dashboard,
            :read_compliance_adherence_report,
            :read_compliance_violations_report
          ]
        end

        it_behaves_like 'custom roles abilities'
      end

      context 'for a custom role with the `read_compliance_dashboard` ability' do
        let(:licensed_features) do
          {
            project_level_compliance_dashboard: true,
            project_level_compliance_adherence_report: true,
            project_level_compliance_violations_report: true
          }
        end

        let(:member_role_abilities) { { read_compliance_dashboard: true } }

        let(:allowed_abilities) do
          [
            :read_compliance_dashboard,
            :read_compliance_adherence_report,
            :read_compliance_violations_report
          ]
        end

        it_behaves_like 'custom roles abilities'
      end

      context 'for a member role with `admin_web_hook` true' do
        let(:member_role_abilities) { { admin_web_hook: true } }
        let(:allowed_abilities) { [:admin_web_hook, :read_web_hook] }

        it_behaves_like 'custom roles abilities'
      end

      context 'for a member role with `manage_deploy_tokens` true' do
        let(:member_role_abilities) { { manage_deploy_tokens: true } }
        let(:allowed_abilities) { [:manage_deploy_tokens, :read_deploy_token, :create_deploy_token, :destroy_deploy_token] }

        it_behaves_like 'custom roles abilities'
      end

      context 'for a custom role with the `manage_merge_request_settings` ability' do
        let(:member_role_abilities) { { read_code: true, manage_merge_request_settings: true } }
        let(:allowed_abilities) do
          [
            :manage_merge_request_settings,
            :edit_approval_rule,
            :modify_approvers_rules,
            :modify_merge_request_author_setting,
            :modify_merge_request_committer_setting
          ]
        end

        it_behaves_like 'custom roles abilities'

        context 'when `target_branch_rules` feature is available' do
          let(:licensed_features) { { target_branch_rules: true } }
          let(:allowed_abilities) { [:admin_target_branch_rule] }

          it_behaves_like 'custom roles abilities'
        end

        context 'when `merge_request_approvers` feature is available' do
          let(:licensed_features) { { merge_request_approvers: true } }
          let(:allowed_abilities) { [:admin_merge_request_approval_settings] }

          it_behaves_like 'custom roles abilities'
        end
      end

      context 'for a custom role with the `admin_integrations` ability' do
        let(:member_role_abilities) { { admin_integrations: true } }
        let(:allowed_abilities) { [:admin_integrations] }

        it_behaves_like 'custom roles abilities'
      end

      context 'for a custom role with the `read_runners` ability' do
        let(:member_role_abilities) { { read_runners: true } }
        let(:allowed_abilities) { [:read_project_runners, :read_runner] }

        it_behaves_like 'custom roles abilities'
      end

      context 'for a member role with `admin_protected_branch` true' do
        let(:member_role_abilities) { { admin_protected_branch: true } }
        let(:allowed_abilities) do
          [:admin_protected_branch, :read_protected_branch, :create_protected_branch,
           :update_protected_branch, :destroy_protected_branch]
        end

        it_behaves_like 'custom roles abilities'
      end

      context 'for a custom role with the `admin_security_testing` ability' do
        let(:member_role_abilities) { { admin_security_testing: true } }
        let(:licensed_features) do
          { security_dashboard: true,
            security_scans_api: true,
            security_on_demand_scans: true,
            coverage_fuzzing: true,
            secret_push_protection: true,
            secret_detection_validity_checks: true,
            container_scanning_for_registry: true,
            project_level_compliance_dashboard: true }
        end

        # shared in SaaS and non-SaaS scenarios
        let(:abilities) do
          [
            :access_security_and_compliance,
            :read_security_configuration,
            :read_on_demand_dast_scan,
            :create_on_demand_dast_scan,
            :edit_on_demand_dast_scan,
            :enable_secret_push_protection,
            :configure_secret_detection_validity_checks,
            :read_project_security_dashboard,
            :read_project_security_exclusions,
            :read_coverage_fuzzing,
            :create_coverage_fuzzing_corpus,
            :enable_container_scanning_for_registry,
            :push_code,
            :create_merge_request_from,
            :create_pipeline,
            :build_download_code,
            :read_merge_request,
            :download_code,
            :read_project_runners,
            :read_secret_push_protection_info,
            :update_secret_detection_validity_checks_status
          ]
        end

        let(:allowed_abilities) { abilities }

        before do
          # Ensure merge requests are enabled for the project
          project.project_feature.update!(merge_requests_access_level: ProjectFeature::ENABLED)
        end

        it_behaves_like 'custom roles abilities'

        context 'when on SaaS', :saas do
          #  access_security_scans_api is only available on SaaS while in beta
          let(:allowed_abilities) { abilities + [:access_security_scans_api] }

          it_behaves_like 'custom roles abilities'
        end
      end
    end

    context 'admin custom role', :enable_admin_mode do
      let_it_be(:project) { create(:project, :private, public_builds: false) }
      let_it_be(:non_admin_user) { create(:user) }

      let(:member_role_abilities) { [] }
      let(:allowed_abilities) { [] }
      let(:current_user) { non_admin_user }

      subject { described_class.new(current_user, project) }

      shared_examples 'admin custom roles abilities' do
        context 'when custom roles feature is unavailable' do
          before do
            create(:admin_member_role, *member_role_abilities, user: current_user)

            stub_licensed_features(custom_roles: false)
          end

          it { expect_disallowed(*allowed_abilities) }
        end

        context 'when custom roles feature is available' do
          before do
            stub_licensed_features(custom_roles: true)
          end

          context 'when a role enables the abilities' do
            before do
              create(:admin_member_role, *member_role_abilities, user: current_user)
            end

            it { expect_allowed(*allowed_abilities) }
          end

          context 'when a role does not enable the abilities' do
            it { expect_disallowed(*allowed_abilities) }
          end
        end
      end

      context 'for an admin member role with read_admin_cicd true' do
        let(:member_role_abilities) { [:read_admin_cicd] }
        let(:allowed_abilities) { %i[read_project_metadata] }

        it_behaves_like 'admin custom roles abilities'
      end
    end

    describe 'permissions for suggested reviewers bot', :saas do
      let(:permissions) { [:admin_project_member, :create_resource_access_tokens] }
      let(:namespace) { build_stubbed(:namespace) }
      let(:project) { build_stubbed(:project, namespace: namespace) }

      context 'when user is suggested_reviewers_bot' do
        let(:current_user) { Users::Internal.suggested_reviewers_bot }

        where(:suggested_reviewers_available, :token_creation_allowed, :allowed) do
          false | false | false
          false | true  | false
          true  | false | false
          true  | true  | true
        end

        with_them do
          before do
            allow(project).to receive(:can_suggest_reviewers?).and_return(suggested_reviewers_available)

            allow(::Gitlab::CurrentSettings)
              .to receive(:personal_access_tokens_disabled?)
              .and_return(!token_creation_allowed)
          end

          it 'always allows permissions except when feature disabled' do
            if allowed
              expect_allowed(*permissions)
            else
              expect_disallowed(*permissions)
            end
          end
        end
      end

      context 'when user is not suggested_reviewers_bot' do
        let(:current_user) { developer }

        before do
          allow(project).to receive(:can_suggest_reviewers?).and_return(true)

          allow(::Gitlab::CurrentSettings)
            .to receive(:personal_access_tokens_disabled?)
            .and_return(false)
        end

        it 'does not allow permissions' do
          expect_disallowed(*permissions)
        end
      end
    end

    describe 'read_project_runners' do
      context 'with auditor' do
        let(:current_user) { auditor }

        it { is_expected.to be_allowed(:read_project_runners) }
      end
    end

    describe 'read_runner_usage' do
      where(:licensed, :current_user, :project, :enable_admin_mode, :clickhouse_configured, :expected) do
        true  | ref(:admin)      | ref(:public_project_in_group) | true  | true  | true
        false | ref(:maintainer) | ref(:public_project_in_group) | false | true  | false
        true  | ref(:maintainer) | ref(:public_project_in_group) | false | false | false
        true  | ref(:maintainer) | ref(:public_project_in_group) | false | true  | true
        true  | ref(:auditor)    | ref(:public_project_in_group) | false | true  | false
        true  | ref(:developer)  | ref(:public_project_in_group) | false | true  | false
        true  | ref(:admin)      | ref(:public_project)          | true  | true  | false
        true  | ref(:maintainer) | ref(:public_project)          | false | true  | false
      end

      with_them do
        before do
          stub_licensed_features(runner_performance_insights_for_namespace: licensed)

          enable_admin_mode!(admin) if enable_admin_mode

          allow(::Gitlab::ClickHouse).to receive(:configured?).and_return(clickhouse_configured)
        end

        it 'matches expectation' do
          if expected
            is_expected.to be_allowed(:read_runner_usage)
          else
            is_expected.to be_disallowed(:read_runner_usage)
          end
        end
      end
    end

    describe 'workspace creation' do
      context 'with no user' do
        let(:current_user) { nil }

        it { is_expected.to be_disallowed(:create_workspace) }
      end

      context 'with an authorized user' do
        let(:current_user) { developer }

        it { is_expected.to be_allowed(:create_workspace) }
      end
    end

    describe 'create_pipeline policy' do
      context 'as a guest member' do
        let(:current_user) { guest }

        it { is_expected.not_to be_allowed(:create_pipeline) }

        context 'and user is a security_policy_bot' do
          let_it_be(:security_policy_bot) { create(:user, user_type: :security_policy_bot) }
          let(:current_user) { security_policy_bot }

          it { is_expected.not_to be_allowed(:create_pipeline) }

          shared_examples 'allows to create pipeline' do
            let(:security_policy_bot) { create(:user, user_type: :security_policy_bot) }

            before do
              project.add_guest(security_policy_bot)
            end

            it { is_expected.to be_allowed(:create_pipeline) }
          end

          context 'and user is a member of the project' do
            context 'and the project is private' do
              let(:project) { private_project }

              it_behaves_like 'allows to create pipeline'
            end

            context 'and the project is internal' do
              let(:project) { internal_project }

              it_behaves_like 'allows to create pipeline'
            end

            context 'and the project is public' do
              let(:project) { public_project }

              it_behaves_like 'allows to create pipeline'
            end

            context 'and the project is public in group' do
              let(:project) { public_project_in_group }

              it_behaves_like 'allows to create pipeline'
            end
          end
        end
      end
    end

    describe 'build_download_code policy' do
      let(:project) { private_project }

      context 'as a guest member' do
        let(:current_user) { guest }

        it { is_expected.not_to be_allowed(:build_download_code) }

        context 'and user is a security_policy_bot' do
          let_it_be(:security_policy_bot) { create(:user, user_type: :security_policy_bot) }
          let(:current_user) { security_policy_bot }

          it { is_expected.not_to be_allowed(:build_download_code) }

          context 'and user is a member of the project' do
            before do
              [private_project, internal_project, public_project, public_project_in_group].each do |project|
                project.add_guest(security_policy_bot)
              end
            end

            it { is_expected.to be_allowed(:build_download_code) }
          end
        end
      end
    end

    describe 'create_bot_pipeline policy' do
      context 'as a guest member' do
        let(:current_user) { guest }

        it { is_expected.not_to be_allowed(:create_bot_pipeline) }

        context 'and user is a security_policy_bot' do
          let_it_be(:security_policy_bot) { create(:user, user_type: :security_policy_bot) }
          let(:current_user) { security_policy_bot }

          it { is_expected.not_to be_allowed(:create_bot_pipeline) }

          context 'and user is a member of the project' do
            shared_examples 'allows to create_bot_pipeline' do
              let(:security_policy_bot) { create(:user, user_type: :security_policy_bot) }

              before do
                project.add_guest(security_policy_bot)
              end

              it { is_expected.to be_allowed(:create_bot_pipeline) }
            end

            context 'and the project is private' do
              let(:project) { private_project }

              it_behaves_like 'allows to create_bot_pipeline'
            end

            context 'and the project is internal' do
              let(:project) { internal_project }

              it_behaves_like 'allows to create_bot_pipeline'
            end

            context 'and the project is public' do
              let(:project) { public_project }

              it_behaves_like 'allows to create_bot_pipeline'
            end

            context 'and the project is public in group' do
              let(:project) { public_project_in_group }

              it_behaves_like 'allows to create_bot_pipeline'
            end
          end
        end
      end
    end

    describe 'security_policy_bot policy' do
      let_it_be(:security_policy_bot) { create(:user, user_type: :security_policy_bot) }
      let(:current_user) { security_policy_bot }

      context 'when user is authenticated via CI_JOB_TOKEN', :request_store do
        let(:project) { public_project }
        let(:job) { build_stubbed(:ci_build, project: scope_project, user: current_user) }
        let(:scope_project) { project }

        let_it_be(:other_private_project) { create(:project, :private) }

        before do
          allow(::Gitlab::CurrentSettings).to receive(:enforce_ci_inbound_job_token_scope_enabled?).and_return(instance_level_token_scope_enabled)
          project.add_guest(security_policy_bot)
          current_user.set_ci_job_token_scope!(job)
          project.update!(
            ci_outbound_job_token_scope_enabled: token_scope_enabled,
            ci_inbound_job_token_scope_enabled: token_scope_enabled
          )
          scope_project.update!(
            ci_outbound_job_token_scope_enabled: token_scope_enabled,
            ci_inbound_job_token_scope_enabled: token_scope_enabled
          )
        end

        context 'when instance_level_token_scope_enabled is false' do
          let(:instance_level_token_scope_enabled) { false }

          context 'when token scope is disabled' do
            let(:token_scope_enabled) { false }

            context 'when pipeline is executed in project where bot is invited' do
              it { is_expected.to be_allowed(:create_pipeline) }
              it { is_expected.to be_allowed(:create_bot_pipeline) }
              it { is_expected.to be_allowed(:build_download_code) }
            end

            context 'when pipeline is executed in project where bot is not invited' do
              let(:scope_project) { other_private_project }

              it { is_expected.to be_allowed(:create_pipeline) }
              it { is_expected.to be_allowed(:create_bot_pipeline) }
              it { is_expected.to be_allowed(:build_download_code) }
            end
          end

          context 'when token scope is enabled' do
            let(:token_scope_enabled) { true }

            context 'when pipeline is executed in project where bot is invited' do
              it { is_expected.to be_allowed(:create_pipeline) }
              it { is_expected.to be_allowed(:create_bot_pipeline) }
              it { is_expected.to be_allowed(:build_download_code) }
            end

            context 'when pipeline is executed in project where bot is not invited' do
              let(:scope_project) { other_private_project }

              it { is_expected.to be_disallowed(:create_pipeline) }
              it { is_expected.to be_disallowed(:create_bot_pipeline) }
              it { is_expected.to be_disallowed(:build_download_code) }
            end
          end
        end

        context 'when instance_level_token_scope_enabled is true' do
          let(:instance_level_token_scope_enabled) { true }

          context 'when token scope is disabled' do
            let(:token_scope_enabled) { false }

            context 'when pipeline is executed in project where bot is invited' do
              it { is_expected.to be_allowed(:create_pipeline) }
              it { is_expected.to be_allowed(:create_bot_pipeline) }
              it { is_expected.to be_allowed(:build_download_code) }
            end

            context 'when pipeline is executed in project where bot is not invited' do
              let(:scope_project) { other_private_project }

              it { is_expected.to be_disallowed(:create_pipeline) }
              it { is_expected.to be_disallowed(:create_bot_pipeline) }
              it { is_expected.to be_disallowed(:build_download_code) }
            end
          end
        end
      end

      context 'when security policy bot is on the project' do
        before do
          project.add_guest(security_policy_bot)
        end

        context 'when security_dashboard is not enabled' do
          it { is_expected.to be_disallowed(:create_vulnerability_state_transition) }
        end

        context 'when security_dashboard is enabled' do
          before do
            stub_licensed_features(security_dashboard: true)
          end

          it { is_expected.to be_allowed(:create_vulnerability_state_transition) }
        end
      end
    end

    describe 'download_code_spp_repository policy' do
      let(:current_user) { guest }

      it { is_expected.not_to be_allowed(:download_code_spp_repository) }

      context 'when project is a security policy project' do
        before do
          create(:security_orchestration_policy_configuration, security_policy_management_project: project)
        end

        context 'and the project is private' do
          let(:project) { private_project }

          it { is_expected.to be_allowed(:download_code_spp_repository) }
        end

        context 'and the project is internal' do
          let(:project) { internal_project }

          it { is_expected.to be_allowed(:download_code_spp_repository) }
        end

        context 'and the project is public' do
          let(:project) { public_project }

          it { is_expected.to be_allowed(:download_code_spp_repository) }
        end

        context 'and the project is public in group' do
          let(:project) { public_project_in_group }

          it { is_expected.to be_allowed(:download_code_spp_repository) }
        end

        context 'and the spp_repository_pipeline_access setting is disabled' do
          before do
            project.project_setting.update!(spp_repository_pipeline_access: false)
          end

          it { is_expected.not_to be_allowed(:download_code_spp_repository) }
        end

        context 'and namespace allows spp_repository_pipeline_access' do
          before do
            project.group.namespace_settings.update!(spp_repository_pipeline_access: true)
          end

          context 'and the project is private in group' do
            let(:project) { private_project_in_group }

            it { is_expected.to be_allowed(:download_code_spp_repository) }
          end

          context 'and the project is internal in group' do
            let_it_be_with_refind(:internal_project_in_group) { create(:project, :internal, namespace: group) }
            let(:project) { internal_project_in_group }

            it { is_expected.to be_allowed(:download_code_spp_repository) }
          end

          context 'and the project is public in group' do
            let(:project) { public_project_in_group }

            it { is_expected.to be_allowed(:download_code_spp_repository) }
          end
        end

        context 'and application setting allows spp_repository_pipeline_access' do
          before do
            stub_application_setting(spp_repository_pipeline_access: true)
          end

          context 'and the project is private' do
            let(:project) { private_project }

            it { is_expected.to be_allowed(:download_code_spp_repository) }
          end

          context 'and the project is internal' do
            let(:project) { internal_project }

            it { is_expected.to be_allowed(:download_code_spp_repository) }
          end

          context 'and the project is public' do
            let(:project) { public_project }

            it { is_expected.to be_allowed(:download_code_spp_repository) }
          end

          context 'and the project is public in group' do
            let(:project) { public_project_in_group }

            it { is_expected.to be_allowed(:download_code_spp_repository) }
          end
        end
      end

      context 'when user is authenticated via CI_JOB_TOKEN', :request_store do
        let(:job) { build_stubbed(:ci_build, project: scope_project, user: current_user) }
        let(:scope_project) { project }

        let_it_be(:other_private_project) { create(:project, :private) }

        before do
          allow(::Gitlab::CurrentSettings).to receive(:enforce_ci_inbound_job_token_scope_enabled?).and_return(instance_level_token_scope_enabled)
          current_user.set_ci_job_token_scope!(job)
          create(:security_orchestration_policy_configuration, security_policy_management_project: project)
          project.project_setting.update!(spp_repository_pipeline_access: true)
          project.update!(
            ci_outbound_job_token_scope_enabled: token_scope_enabled,
            ci_inbound_job_token_scope_enabled: token_scope_enabled
          )
          scope_project.update!(
            ci_outbound_job_token_scope_enabled: token_scope_enabled,
            ci_inbound_job_token_scope_enabled: token_scope_enabled
          )
        end

        context 'when instance_level_token_scope_enabled is false' do
          let(:instance_level_token_scope_enabled) { false }

          context 'when token scope is disabled' do
            let(:token_scope_enabled) { false }

            context 'when accessing from the same project' do
              it { is_expected.to be_allowed(:download_code_spp_repository) }
            end

            context 'when accessing from other project' do
              let(:scope_project) { other_private_project }

              it { is_expected.to be_allowed(:download_code_spp_repository) }
            end
          end

          context 'when token scope is enabled' do
            let(:token_scope_enabled) { true }

            context 'when accessing from the same project' do
              it { is_expected.to be_allowed(:download_code_spp_repository) }
            end

            context 'when accessing from other project' do
              let(:scope_project) { other_private_project }

              it { is_expected.to be_disallowed(:download_code_spp_repository) }
            end
          end
        end

        context 'when instance_level_token_scope_enabled is true' do
          let(:instance_level_token_scope_enabled) { true }

          context 'when token scope is enabled' do
            let(:token_scope_enabled) { false }

            context 'when accessing from the same project' do
              it { is_expected.to be_allowed(:download_code_spp_repository) }
            end

            context 'when accessing from other project' do
              let(:scope_project) { other_private_project }

              it { is_expected.to be_disallowed(:download_code_spp_repository) }
            end
          end
        end
      end
    end

    describe 'generate_description' do
      let(:authorizer) { instance_double(::Gitlab::Llm::FeatureAuthorizer) }
      let(:current_user) { guest }
      let(:project) { private_project }

      before do
        allow(::Gitlab::Llm::FeatureAuthorizer).to receive(:new).and_return(authorizer)
      end

      context "when feature is authorized" do
        before do
          allow(authorizer).to receive(:allowed?).and_return(true)
        end

        context 'when user can create issue' do
          it { is_expected.to be_allowed(:generate_description) }
        end

        context 'when user cannot create issue' do
          let(:current_user) { create(:user) }

          it { is_expected.to be_disallowed(:generate_description) }
        end
      end

      context "when feature is not authorized" do
        before do
          allow(authorizer).to receive(:allowed?).and_return(false)
        end

        it { is_expected.to be_disallowed(:generate_description) }
      end
    end

    describe 'access_summarize_new_merge_request' do
      let(:authorizer) { instance_double(::Gitlab::Llm::FeatureAuthorizer) }
      let(:current_user) { user_can_create_mr ? developer : nil }

      where(:feature_flag_enabled, :llm_authorized, :user_can_create_mr, :expected_result) do
        true  | true  | true  | be_allowed(:access_summarize_new_merge_request)
        true  | true  | false | be_disallowed(:access_summarize_new_merge_request)
        true  | false | true  | be_disallowed(:access_summarize_new_merge_request)
        false | true  | true  | be_disallowed(:access_summarize_new_merge_request)
      end

      with_them do
        before do
          # Setup feature flag
          stub_feature_flags(add_ai_summary_for_new_mr: feature_flag_enabled)

          # Setup LLM authorizer
          allow(::Gitlab::Llm::FeatureAuthorizer).to receive(:new).and_return(authorizer)
          allow(authorizer).to receive(:allowed?).and_return(llm_authorized)
        end

        it { is_expected.to expected_result }
      end
    end

    describe 'admin_target_branch_rule policy' do
      let(:current_user) { owner }

      describe 'when the project does not have the correct license' do
        before do
          stub_licensed_features(target_branch_rules: false)
        end

        it { is_expected.to be_disallowed(:admin_target_branch_rule) }
      end

      describe 'when the user does not have permissions' do
        let(:current_user) { auditor }

        it { is_expected.to be_disallowed(:admin_target_branch_rule) }
      end

      describe 'when the user has permission' do
        before do
          stub_licensed_features(target_branch_rules: true)
        end

        it { is_expected.to be_allowed(:admin_target_branch_rule) }
      end
    end

    describe 'read_target_branch_rule policy' do
      let(:current_user) { owner }

      describe 'when the user has permission' do
        before do
          stub_licensed_features(target_branch_rules: true)
        end

        it { is_expected.to be_allowed(:read_target_branch_rule) }
      end
    end

    describe 'read_observability policy' do
      let(:current_user) { reporter }

      before do
        stub_licensed_features(observability: true)
      end

      describe 'when observability_features is disabled' do
        before do
          stub_feature_flags(observability_features: false)
        end

        it { is_expected.to be_disallowed(:read_observability) }
      end

      describe 'when observability feature flag is enabled for root namespace' do
        before do
          stub_feature_flags(observability_features: project.root_namespace)
        end

        it { is_expected.to be_allowed(:read_observability) }
      end

      describe 'when the project does not have the correct license' do
        before do
          stub_feature_flags(observability_features: true)
          stub_licensed_features(observability: false)
        end

        it { is_expected.to be_disallowed(:read_observability) }
      end

      describe 'when the user does not have permission' do
        let(:current_user) { guest }

        before do
          stub_feature_flags(observability_features: true)
          stub_licensed_features(observability: true)
        end

        it { is_expected.to be_disallowed(:read_observability) }
      end

      describe 'when the user has permission' do
        before do
          stub_feature_flags(observability_features: true)
          stub_licensed_features(observability: true)
        end

        it { is_expected.to be_allowed(:read_observability) }
      end
    end

    describe 'write_observability policy' do
      let(:current_user) { developer }

      before do
        stub_licensed_features(observability: true)
      end

      describe 'when observability_features feature flag is disabled' do
        before do
          stub_feature_flags(observability_features: false)
        end

        it { is_expected.to be_disallowed(:write_observability) }
      end

      describe 'when observability feature flag is enabled for root namespace' do
        before do
          stub_feature_flags(observability_features: project.root_namespace)
        end

        it { is_expected.to be_allowed(:write_observability) }
      end

      describe 'when the project does not have the correct license' do
        before do
          stub_feature_flags(observability_features: true)
          stub_licensed_features(observability: false)
        end

        it { is_expected.to be_disallowed(:write_observability) }
      end

      describe 'when the user does not have permission' do
        let(:current_user) { reporter }

        before do
          stub_feature_flags(observability_features: true)
          stub_licensed_features(observability: true)
        end

        it { is_expected.to be_disallowed(:write_observability) }
      end

      describe 'when the user has permission' do
        before do
          stub_feature_flags(observability_features: true)
          stub_licensed_features(observability: true)
        end

        it { is_expected.to be_allowed(:write_observability) }
      end
    end

    describe "#admin_vulnerability" do
      before do
        stub_licensed_features(security_dashboard: true)
      end

      let(:expected_permissions) do
        [
          :admin_vulnerability,
          :read_vulnerability,
          :create_vulnerability_feedback,
          :destroy_vulnerability_feedback,
          :update_vulnerability_feedback,
          :create_vulnerability_state_transition
        ]
      end

      context "with guest" do
        let(:current_user) { guest }

        it { is_expected.to be_disallowed(:admin_vulnerability) }
      end

      context "with planner" do
        let(:current_user) { planner }

        it { is_expected.to be_disallowed(:admin_vulnerability) }
      end

      context "with reporter" do
        let(:current_user) { reporter }

        it { is_expected.to be_disallowed(:admin_vulnerability) }
      end

      context "with developer" do
        let(:current_user) { developer }

        it { is_expected.to be_disallowed(:admin_vulnerability) }
      end

      context "with maintainer" do
        let(:current_user) { maintainer }

        it { is_expected.to be_allowed(*expected_permissions) }
      end

      context "with owner" do
        let(:current_user) { owner }

        it { is_expected.to be_allowed(*expected_permissions) }
      end
    end

    describe 'generate_cube_query policy' do
      let(:current_user) { owner }
      let(:authorizer) { instance_double(::Gitlab::Llm::FeatureAuthorizer) }

      where(:ai_global_switch, :flag_enabled, :licensed, :allowed) do
        true | true | true | true
        true | true | false | false
        true | false | true | false
        true | false | false | false
        false | true | true | false
        false | true | false | false
        false | false | true | false
        false | false | false | false
      end

      with_them do
        before do
          stub_feature_flags(ai_global_switch: ai_global_switch)
          stub_feature_flags(generate_cube_query: flag_enabled)
          allow(::Gitlab::Llm::FeatureAuthorizer).to receive(:new).and_return(authorizer)
          allow(authorizer).to receive(:allowed?).and_return(licensed)
        end

        it 'permits the correct abilities' do
          if allowed
            is_expected.to be_allowed(:generate_cube_query)
          else
            is_expected.to be_disallowed(:generate_cube_query)
          end
        end
      end
    end

    describe 'read_ai_agents' do
      where(:feature_flag_enabled, :licensed_feature, :current_user, :allowed) do
        true  | true  | ref(:owner)      | true
        true  | true  | ref(:reporter)   | true
        true  | true  | ref(:planner)    | true
        true  | true  | ref(:guest)      | true
        true  | true  | ref(:non_member) | false
        true  | false | ref(:owner)      | false
        true  | false | ref(:reporter)   | false
        true  | false | ref(:planner)    | false
        true  | false | ref(:guest)      | false
        true  | false | ref(:non_member) | false
        false | true  | ref(:owner)      | false
        false | true  | ref(:reporter)   | false
        false | true  | ref(:planner)    | false
        false | true  | ref(:guest)      | false
        false | true  | ref(:non_member) | false
        false | false | ref(:owner)      | false
        false | false | ref(:reporter)   | false
        false | false | ref(:planner)    | false
        false | false | ref(:guest)      | false
        false | false | ref(:non_member) | false
      end
      with_them do
        before do
          stub_feature_flags(agent_registry: feature_flag_enabled)
          stub_licensed_features(ai_agents: licensed_feature)
        end

        if params[:allowed]
          it { expect_allowed(:read_ai_agents) }
        else
          it { expect_disallowed(:read_ai_agents) }
        end
      end
    end

    describe 'write_ai_agents' do
      where(:feature_flag_enabled, :licensed_feature, :current_user, :allowed) do
        true  | true  | ref(:owner)      | true
        true  | true  | ref(:reporter)   | true
        true  | true  | ref(:planner)    | false
        true  | true  | ref(:guest)      | false
        true  | true  | ref(:non_member) | false
        true  | false | ref(:owner)      | false
        true  | false | ref(:reporter)   | false
        true  | false | ref(:planner)    | false
        true  | false | ref(:guest)      | false
        true  | false | ref(:non_member) | false
        false | true  | ref(:owner)      | false
        false | true  | ref(:reporter)   | false
        false | true  | ref(:planner)    | false
        false | true  | ref(:guest)      | false
        false | true  | ref(:non_member) | false
        false | false | ref(:owner)      | false
        false | false | ref(:reporter)   | false
        false | false | ref(:planner)    | false
        false | false | ref(:guest)      | false
        false | false | ref(:non_member) | false
      end
      with_them do
        before do
          stub_feature_flags(agent_registry: feature_flag_enabled)
          stub_licensed_features(ai_agents: licensed_feature)
        end

        if params[:allowed]
          it { expect_allowed(:write_ai_agents) }
        else
          it { expect_disallowed(:write_ai_agents) }
        end
      end
    end

    describe 'access_duo_chat' do
      let_it_be(:current_user) { create(:user) }
      let(:project) { create(:project, :public, group: group) }

      subject { described_class.new(current_user, project) }

      context 'when on SaaS instance', :saas do
        let_it_be_with_reload(:group) { create(:group_with_plan, plan: :premium_plan) }

        context 'when container is a group with AI enabled' do
          include_context 'with duo features enabled and ai chat available for group on SaaS'

          context 'when user is a member of the group' do
            before do
              group.add_guest(current_user)
            end

            it { is_expected.to be_allowed(:access_duo_chat) }

            context 'when the group does not have an Premium SaaS license' do
              let_it_be(:group) { create(:group) }

              it { is_expected.to be_disallowed(:access_duo_chat) }
            end
          end

          context 'when user is not a member of the parent group' do
            context 'when the user has AI enabled via another group' do
              context 'user can view project' do
                it 'is allowed' do
                  is_expected.to be_allowed(:access_duo_chat)
                end
              end

              context 'user cannot view project' do
                before do
                  project.update!(visibility_level: Gitlab::VisibilityLevel::PRIVATE)
                end

                it 'is not allowed' do
                  is_expected.to be_disallowed(:access_duo_chat)
                end
              end
            end
          end

          context 'when user is a member of the project' do
            before do
              project.add_guest(current_user)
            end

            context 'when the user has AI enabled through parent group' do
              it 'is allowed' do
                is_expected.to be_allowed(:access_duo_chat)
              end
            end
          end
        end
      end

      context 'for self-managed', :with_cloud_connector do
        let_it_be_with_reload(:group) { create(:group) }
        let(:policy) { :access_duo_chat }

        before do
          project.add_guest(current_user)
        end

        context 'when not on .org or .com' do
          where(:enabled_for_user, :duo_features_enabled, :duo_chat_matcher) do
            true  | false | be_disallowed(policy)
            true  | true  | be_allowed(policy)
            false | false | be_disallowed(policy)
            false | true  | be_disallowed(policy)
          end

          with_them do
            before do
              allow(::Gitlab).to receive(:org_or_com?).and_return(false)
              stub_ee_application_setting(duo_features_enabled: duo_features_enabled, lock_duo_features_enabled: true)
              allow(Ability).to receive(:allowed?).and_call_original
              allow(Ability).to receive(:allowed?).with(current_user, :access_duo_chat).and_return(enabled_for_user)
            end

            it { is_expected.to duo_chat_matcher }
          end
        end
      end
    end

    context 'access_duo_features' do
      let(:project) { private_project }

      where(:current_user, :duo_features_enabled, :cs_matcher) do
        ref(:guest) | true | be_allowed(:access_duo_features)
        ref(:guest) | false | be_disallowed(:access_duo_features)
        nil | true | be_disallowed(:access_duo_features)
        nil | false | be_disallowed(:access_duo_features)
      end

      with_them do
        before do
          project.update!(duo_features_enabled: duo_features_enabled)
        end

        it do
          is_expected.to cs_matcher
        end
      end
    end

    describe 'access to project for duo workflow' do
      let_it_be_with_reload(:project) { public_project }

      where(:current_user, :token_info, :duo_features_enabled, :cs_matcher) do
        ref(:guest)      | nil                               | true  | be_allowed(:read_project)
        ref(:guest)      | { token_scopes: [:ai_workflows] } | true  | be_allowed(:read_project)
        ref(:guest)      | { token_scopes: [:ai_workflows] } | false | be_disallowed(:read_project, :admin_project)
        ref(:guest)      | { token_scopes: [:other_scope] }  | true  | be_allowed(:read_project)
        ref(:maintainer) | { token_scopes: [:ai_workflows] } | false | be_disallowed(:read_project, :admin_project)
      end

      with_them do
        before do
          project.update!(duo_features_enabled: duo_features_enabled)
          ::Current.token_info = token_info
        end

        it { is_expected.to cs_matcher }
      end
    end

    describe 'on_demand_scans_enabled policy' do
      let(:current_user) { owner }
      let(:permissions) { [:read_on_demand_dast_scan, :create_on_demand_dast_scan, :edit_on_demand_dast_scan] }

      where(:feature_available, :allowed) do
        false | false
        true | true
      end

      with_them do
        context "when feature is #{params[:feature_available] ? 'available' : 'unavailable'}" do
          before do
            stub_licensed_features(security_on_demand_scans: feature_available)
          end

          it "on demand scan permissions are #{params[:allowed] ? 'allowed' : 'disallowed'}" do
            if allowed
              expect_allowed(*permissions)
            else
              expect_disallowed(*permissions)
            end
          end
        end
      end
    end

    describe 'read_runner_cloud_provisioning_info policy' do
      let(:current_user) { maintainer }

      it { is_expected.to be_disallowed(:read_runner_cloud_provisioning_info) }

      context 'when SaaS-only feature is available' do
        before do
          stub_saas_features(google_cloud_support: true)
        end

        context 'the user is a maintainer' do
          let(:current_user) { maintainer }

          it { is_expected.to be_allowed(:read_runner_cloud_provisioning_info) }
        end

        context 'the user is a guest' do
          let(:current_user) { guest }

          it { is_expected.to be_disallowed(:read_runner_cloud_provisioning_info) }
        end
      end
    end

    describe 'read_runner_gke_provisioning_info policy' do
      let(:current_user) { maintainer }

      it { is_expected.to be_disallowed(:read_runner_gke_provisioning_info) }

      context 'when SaaS-only feature is available' do
        before do
          stub_saas_features(google_cloud_support: true)
        end

        context 'the user is a maintainer' do
          let(:current_user) { maintainer }

          it { is_expected.to be_allowed(:read_runner_gke_provisioning_info) }
        end

        context 'the user is a guest' do
          let(:current_user) { guest }

          it { is_expected.to be_disallowed(:read_runner_gke_provisioning_info) }
        end
      end
    end

    describe 'provision_cloud_runner policy' do
      let(:current_user) { maintainer }

      it { is_expected.to be_disallowed(:provision_cloud_runner) }

      context 'when SaaS-only feature is available' do
        before do
          stub_saas_features(google_cloud_support: true)
        end

        context 'the user is a maintainer' do
          let(:current_user) { maintainer }

          it { is_expected.to be_allowed(:provision_cloud_runner) }
        end

        context 'the user is a guest' do
          let(:current_user) { guest }

          it { is_expected.to be_disallowed(:provision_cloud_runner) }
        end
      end
    end

    describe 'provision_gke_runner policy' do
      let(:current_user) { maintainer }

      it { is_expected.to be_disallowed(:provision_gke_runner) }

      context 'when SaaS-only feature is available' do
        before do
          stub_saas_features(google_cloud_support: true)
        end

        context 'the user is a maintainer' do
          let(:current_user) { maintainer }

          it { is_expected.to be_allowed(:provision_gke_runner) }
        end

        context 'the user is a guest' do
          let(:current_user) { guest }

          it { is_expected.to be_disallowed(:provision_gke_runner) }
        end
      end
    end

    describe 'read_google_cloud_artifact_registry' do
      where(:saas_feature_enabled, :current_user, :match_expected_result) do
        true  | ref(:owner)      | be_allowed(:read_google_cloud_artifact_registry)
        true  | ref(:reporter)   | be_allowed(:read_google_cloud_artifact_registry)
        true  | ref(:planner)    | be_disallowed(:read_google_cloud_artifact_registry)
        true  | ref(:guest)      | be_disallowed(:read_google_cloud_artifact_registry)
        true  | ref(:non_member) | be_disallowed(:read_google_cloud_artifact_registry)
        false | ref(:owner)      | be_disallowed(:read_google_cloud_artifact_registry)
        false | ref(:reporter)   | be_disallowed(:read_google_cloud_artifact_registry)
        false | ref(:planner)    | be_disallowed(:read_google_cloud_artifact_registry)
        false | ref(:guest)      | be_disallowed(:read_google_cloud_artifact_registry)
        false | ref(:non_member) | be_disallowed(:read_google_cloud_artifact_registry)
      end

      with_them do
        before do
          stub_saas_features(google_cloud_support: saas_feature_enabled)
        end

        it { is_expected.to match_expected_result }
      end
    end

    describe 'admin_google_cloud_artifact_registry' do
      where(:saas_feature_enabled, :current_user, :match_expected_result) do
        true  | ref(:owner)      | be_allowed(:admin_google_cloud_artifact_registry)
        true  | ref(:maintainer) | be_allowed(:admin_google_cloud_artifact_registry)
        true  | ref(:developer)  | be_disallowed(:admin_google_cloud_artifact_registry)
        true  | ref(:non_member) | be_disallowed(:admin_google_cloud_artifact_registry)
        false | ref(:owner)      | be_disallowed(:admin_google_cloud_artifact_registry)
        false | ref(:maintainer) | be_disallowed(:admin_google_cloud_artifact_registry)
        false | ref(:developer)  | be_disallowed(:admin_google_cloud_artifact_registry)
        false | ref(:non_member) | be_disallowed(:admin_google_cloud_artifact_registry)
      end

      with_them do
        before do
          stub_saas_features(google_cloud_support: saas_feature_enabled)
        end

        it { is_expected.to match_expected_result }
      end
    end

    context 'saved replies permissions' do
      let(:current_user) { owner }

      context 'when no license is present' do
        before do
          stub_licensed_features(project_saved_replies: false)
        end

        it { is_expected.to be_disallowed(:read_saved_replies, :create_saved_replies, :update_saved_replies, :destroy_saved_replies) }
      end

      context 'with correct license' do
        before do
          stub_licensed_features(project_saved_replies: true)
        end

        it { is_expected.to be_allowed(:read_saved_replies, :create_saved_replies, :update_saved_replies, :destroy_saved_replies) }

        context 'when the user is a guest' do
          let(:current_user) { guest }

          it { is_expected.to be_allowed(:read_saved_replies) }

          it { is_expected.to be_disallowed(:create_saved_replies, :update_saved_replies, :destroy_saved_replies) }
        end

        context 'when the user is a reporter' do
          let(:current_user) { reporter }

          it { is_expected.to be_allowed(:read_saved_replies) }

          it { is_expected.to be_disallowed(:create_saved_replies, :update_saved_replies, :destroy_saved_replies) }
        end

        context 'when the user is a developer' do
          let(:current_user) { developer }

          it { is_expected.to be_allowed(:read_saved_replies, :create_saved_replies, :update_saved_replies, :destroy_saved_replies) }
        end

        context 'when the user is a guest member of the project' do
          let(:current_user) { guest }

          it { is_expected.to be_disallowed(:create_saved_replies, :update_saved_replies, :destroy_saved_replies) }
        end
      end
    end

    describe 'enable_secret_push_protection' do
      where(:current_user, :licensed, :match_expected_result) do
        ref(:owner)      | true  | be_allowed(:enable_secret_push_protection)
        ref(:maintainer) | true  | be_allowed(:enable_secret_push_protection)
        ref(:developer)  | true  | be_disallowed(:enable_secret_push_protection)
        ref(:owner)      | false | be_disallowed(:enable_secret_push_protection)
        ref(:maintainer) | false | be_disallowed(:enable_secret_push_protection)
        ref(:developer)  | false | be_disallowed(:enable_secret_push_protection)
      end

      with_them do
        before do
          stub_licensed_features(secret_push_protection: licensed)
        end

        it { is_expected.to match_expected_result }
      end

      describe 'when the project does not have the correct license' do
        let(:current_user) { owner }

        it { is_expected.to be_disallowed(:enable_secret_push_protection) }
      end
    end

    describe 'secret_detection_validity_checks' do
      before do
        stub_feature_flags(validity_checks: true)
        stub_feature_flags(secret_detection_validity_checks_refresh_token: true)
        stub_licensed_features(secret_detection_validity_checks: true)
      end

      describe 'configure_secret_detection_validity_checks' do
        where(:current_user, :match_expected_result) do
          ref(:owner) | be_allowed(:configure_secret_detection_validity_checks)
          ref(:maintainer) | be_allowed(:configure_secret_detection_validity_checks)
          ref(:developer) | be_disallowed(:configure_secret_detection_validity_checks)
        end

        with_them do
          it { is_expected.to match_expected_result }
        end
      end

      describe 'update_secret_detection_validity_checks_status' do
        where(:current_user, :match_expected_result) do
          ref(:owner) | be_allowed(:update_secret_detection_validity_checks_status)
          ref(:maintainer) | be_allowed(:update_secret_detection_validity_checks_status)
          ref(:developer) | be_allowed(:update_secret_detection_validity_checks_status)
        end

        with_them do
          it { is_expected.to match_expected_result }
        end
      end

      context 'when secret_detection_validity_checks licensed feature is not available' do
        before do
          stub_feature_flags(validity_checks: true)
          stub_feature_flags(secret_detection_validity_checks_refresh_token: true)
          stub_licensed_features(secret_detection_validity_checks: false)
        end

        %w[owner maintainer developer].each do |role|
          context "with #{role}" do
            let(:current_user) { send(role) }

            it { is_expected.to be_disallowed(:configure_secret_detection_validity_checks) }
            it { is_expected.to be_disallowed(:update_secret_detection_validity_checks_status) }
          end
        end
      end

      context 'when validity_checks feature flag is disabled' do
        before do
          stub_feature_flags(validity_checks: false)
          stub_feature_flags(secret_detection_validity_checks_refresh_token: true)
          stub_licensed_features(secret_detection_validity_checks: true)
        end

        %w[owner maintainer developer].each do |role|
          context "with #{role}" do
            let(:current_user) { send(role) }

            it { is_expected.to be_disallowed(:configure_secret_detection_validity_checks) }
            it { is_expected.to be_disallowed(:update_secret_detection_validity_checks_status) }
          end
        end
      end

      context 'when secret_detection_validity_checks_refresh_token feature flag is disabled' do
        before do
          stub_feature_flags(validity_checks: true)
          stub_feature_flags(secret_detection_validity_checks_refresh_token: false)
          stub_licensed_features(secret_detection_validity_checks: true)
        end

        %w[owner maintainer].each do |role|
          context "with #{role}" do
            let(:current_user) { send(role) }

            it { is_expected.to be_allowed(:configure_secret_detection_validity_checks) }
            it { is_expected.to be_disallowed(:update_secret_detection_validity_checks_status) }
          end
        end

        context "with developer" do
          let(:current_user) { developer }

          it { is_expected.to be_disallowed(:configure_secret_detection_validity_checks) }
          it { is_expected.to be_disallowed(:update_secret_detection_validity_checks_status) }
        end
      end
    end

    describe 'duo_workflow' do
      let(:project) { public_project_in_group }

      where(:duo_workflow_feature_flag, :stage_check_available, :duo_features_enabled, :current_user, :match_expected_result) do
        true  | true  | true  | ref(:owner)      | be_allowed(:duo_workflow)
        true  | true  | true  | ref(:maintainer) | be_allowed(:duo_workflow)
        true  | true  | true  | ref(:developer)  | be_allowed(:duo_workflow)
        true  | true  | true  | ref(:planner)    | be_disallowed(:duo_workflow)
        true  | true  | true  | ref(:guest)      | be_disallowed(:duo_workflow)
        true  | true  | true  | ref(:non_member) | be_disallowed(:duo_workflow)
        true  | false | true  | ref(:owner)      | be_disallowed(:duo_workflow)
        true  | false | true  | ref(:maintainer) | be_disallowed(:duo_workflow)
        true  | false | true  | ref(:developer)  | be_disallowed(:duo_workflow)
        true  | false | true  | ref(:planner)    | be_disallowed(:duo_workflow)
        true  | false | true  | ref(:guest)      | be_disallowed(:duo_workflow)
        true  | false | true  | ref(:non_member) | be_disallowed(:duo_workflow)
        false | true  | true  | ref(:owner)      | be_disallowed(:duo_workflow)
        false | true  | true  | ref(:maintainer) | be_disallowed(:duo_workflow)
        false | true  | true  | ref(:developer)  | be_disallowed(:duo_workflow)
        false | true  | true  | ref(:planner)    | be_disallowed(:duo_workflow)
        false | true  | true  | ref(:guest)      | be_disallowed(:duo_workflow)
        false | true  | true  | ref(:non_member) | be_disallowed(:duo_workflow)
        false | false | true  | ref(:owner)      | be_disallowed(:duo_workflow)
        false | false | true  | ref(:maintainer) | be_disallowed(:duo_workflow)
        false | false | true  | ref(:developer)  | be_disallowed(:duo_workflow)
        false | false | true  | ref(:planner)    | be_disallowed(:duo_workflow)
        false | false | true  | ref(:guest)      | be_disallowed(:duo_workflow)
        false | false | true  | ref(:non_member) | be_disallowed(:duo_workflow)
        false | false | false | ref(:owner)      | be_disallowed(:duo_workflow)
        false | false | false | ref(:maintainer) | be_disallowed(:duo_workflow)
        false | false | false | ref(:developer)  | be_disallowed(:duo_workflow)
        false | false | false | ref(:planner)    | be_disallowed(:duo_workflow)
        false | false | false | ref(:guest)      | be_disallowed(:duo_workflow)
        false | false | false | ref(:non_member) | be_disallowed(:duo_workflow)
      end

      with_them do
        before do
          stub_feature_flags(duo_workflow: duo_workflow_feature_flag)
          allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(stage_check_available)
          stub_ee_application_setting(duo_features_enabled: duo_features_enabled)
          allow(current_user).to receive(:allowed_to_use?).and_return(false)
        end

        context 'when user is not allowed to use duo_agent_platfrom' do
          it { is_expected.to be_disallowed(:duo_workflow) }
        end

        context 'when user is allowed to use duo_agent_platfrom' do
          before do
            allow(current_user).to receive(:allowed_to_use?).and_return(true)
          end

          it { is_expected.to match_expected_result }
        end
      end
    end

    describe 'enable_container_scanning_for_registry' do
      where(:current_user, :match_expected_result) do
        ref(:owner)      | be_allowed(:enable_container_scanning_for_registry)
        ref(:maintainer) | be_allowed(:enable_container_scanning_for_registry)
        ref(:developer)  | be_disallowed(:enable_container_scanning_for_registry)
        ref(:non_member) | be_disallowed(:enable_container_scanning_for_registry)
      end

      with_them do
        before do
          stub_licensed_features(container_scanning_for_registry: true)
        end

        it { is_expected.to match_expected_result }
      end

      context 'when license feature is not available' do
        where(:current_user, :match_expected_result) do
          ref(:owner)      | be_disallowed(:enable_container_scanning_for_registry)
          ref(:maintainer) | be_disallowed(:enable_container_scanning_for_registry)
          ref(:developer)  | be_disallowed(:enable_container_scanning_for_registry)
          ref(:non_member) | be_disallowed(:enable_container_scanning_for_registry)
        end

        with_them do
          before do
            stub_licensed_features(container_scanning_for_registry: false)
          end

          it { is_expected.to match_expected_result }
        end
      end
    end

    describe 'read_secret_push_protection_info' do
      where(:current_user, :match_expected_result) do
        ref(:owner)      | be_allowed(:read_secret_push_protection_info)
        ref(:maintainer) | be_allowed(:read_secret_push_protection_info)
        ref(:developer)  | be_allowed(:read_secret_push_protection_info)
        ref(:planner)    | be_disallowed(:read_secret_push_protection_info)
        ref(:guest)      | be_disallowed(:read_secret_push_protection_info)
        ref(:non_member) | be_disallowed(:read_secret_push_protection_info)
      end

      with_them do
        before do
          stub_licensed_features(secret_push_protection: true)
        end

        it { is_expected.to match_expected_result }
      end
    end

    describe 'admin_project_secrets_manager' do
      where(:current_user, :match_expected_result) do
        ref(:owner)      | be_allowed(:admin_project_secrets_manager)
        ref(:maintainer) | be_disallowed(:admin_project_secrets_manager)
        ref(:developer)  | be_disallowed(:admin_project_secrets_manager)
        ref(:non_member) | be_disallowed(:admin_project_secrets_manager)
      end

      with_them do
        it { is_expected.to match_expected_result }
      end
    end

    describe 'manage_project_security_exclusions' do
      let(:policy) { :manage_project_security_exclusions }

      where(:role, :allowed) do
        :guest      | false
        :planner    | false
        :reporter   | false
        :developer  | false
        :maintainer | true
        :auditor    | false
        :owner      | true
        :admin      | true
      end

      with_them do
        let(:current_user) { public_send(role) }

        before do
          enable_admin_mode!(current_user) if role == :admin
        end

        it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
      end
    end

    describe 'read_project_security_exclusions' do
      let(:policy) { :read_project_security_exclusions }

      where(:role, :allowed) do
        :guest      | false
        :planner    | false
        :reporter   | false
        :developer  | true
        :maintainer | true
        :auditor    | true
        :owner      | true
        :admin      | true
      end

      with_them do
        let(:current_user) { public_send(role) }

        before do
          enable_admin_mode!(current_user) if role == :admin
        end

        it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
      end
    end

    describe 'manage_security_settings' do
      let(:policy) { :manage_security_settings }

      where(:role, :allowed) do
        :guest      | false
        :reporter   | false
        :developer  | false
        :maintainer | true
        :auditor    | false
        :owner      | true
        :admin      | true
      end

      with_them do
        let(:current_user) { public_send(role) }

        before do
          enable_admin_mode!(current_user) if role == :admin
        end

        it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
      end
    end

    describe 'read_security_settings' do
      let(:policy) { :read_security_settings }

      where(:role, :allowed) do
        :guest      | false
        :reporter   | false
        :developer  | true
        :maintainer | true
        :auditor    | true
        :owner      | true
        :admin      | true
      end

      with_them do
        let(:current_user) { public_send(role) }

        before do
          enable_admin_mode!(current_user) if role == :admin
        end

        it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
      end
    end

    describe 'read_vulnerability_statistics' do
      let(:policy) { :read_vulnerability_statistics }

      where(:role, :allowed) do
        :guest      | false
        :planner    | false
        :reporter   | false
        :developer  | true
        :maintainer | true
        :auditor    | false
        :owner      | true
        :admin      | true
      end

      with_them do
        let(:current_user) { public_send(role) }

        before do
          enable_admin_mode!(current_user) if role == :admin
        end

        it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
      end
    end

    describe 'access_security_scans_api' do
      context 'when on SaaS', :saas do
        context 'when feature is disabled' do
          let(:current_user) { owner }

          before do
            stub_licensed_features(security_scans_api: false)
          end

          it 'is not allowed' do
            is_expected.to be_disallowed(:access_security_scans_api)
          end
        end

        context 'when feature is enabled' do
          where(:current_user, :allowed) do
            ref(:owner)      | true
            ref(:maintainer) | true
            ref(:developer)  | true
            ref(:guest)      | false
            ref(:planner)    | false
            ref(:reporter)   | false
            ref(:non_member) | false
          end

          with_them do
            before do
              stub_licensed_features(security_scans_api: true)
            end

            it { is_expected.to(allowed ? be_allowed(:access_security_scans_api) : be_disallowed(:access_security_scans_api)) }
          end
        end
      end

      context 'when on Self-Managed' do
        # access_security_scans_api is only available on SaaS while in beta
        let(:current_user) { owner }

        before do
          # enable feature explicitly to show that it is still not available because of SaaS check
          stub_licensed_features(security_scans_api: true)
        end

        it 'is not allowed' do
          is_expected.to be_disallowed(:access_security_scans_api)
        end
      end
    end

    describe 'access_ai_review_mr' do
      let(:current_user) { owner }

      where(:duo_features_enabled, :allowed_to_use, :enabled_for_user) do
        true  | false | be_disallowed(:access_ai_review_mr)
        false | true  | be_disallowed(:access_ai_review_mr)
        true  | true  | be_allowed(:access_ai_review_mr)
      end

      with_them do
        before do
          allow(project).to receive(:duo_features_enabled).and_return(duo_features_enabled)

          allow(current_user).to receive(:allowed_to_use?)
            .with(:review_merge_request, licensed_feature: :review_merge_request).and_return(allowed_to_use)
        end

        it { is_expected.to enabled_for_user }
      end
    end
  end

  describe 'invite_group_members policy' do
    let(:app_setting) { :disable_invite_members }
    let(:policy) { :invite_project_members }
    let(:group) { create(:group) }

    context 'when on saas', :saas do
      before do
        allow(project).to receive(:group).and_return(group)

        stub_saas_features(group_disable_invite_members: true)
      end

      context 'with disable_invite_members is available in license' do
        where(:role, :parent_group_setting, :application_setting, :allowed) do
          :guest      | true | true | false
          :planner    | true | true | false
          :reporter   | true | true | false
          :developer  | true | true | false
          :maintainer | false | true | true
          :maintainer | false | false | true
          :maintainer | true | true | false
          :maintainer | true | false | false
          :owner      | false | true | true
          :owner      | false | false | true
          :owner      | true  | true | false
          :owner      | true  | false | false
          :admin      | false | true |  true
          :admin      | false | false | true
          :admin      | false | true | true
          :admin      | false | false | true
        end

        with_them do
          let(:current_user) { public_send(role) }

          before do
            stub_licensed_features(disable_invite_members: true)
            stub_application_setting(app_setting => application_setting)
            allow(project.group).to receive(:disable_invite_members?).and_return(parent_group_setting)
            enable_admin_mode!(current_user) if role == :admin
          end

          it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
        end
      end

      context 'with disable_invite_members not available in license' do
        where(:role, :parent_group_setting, :application_setting, :allowed) do
          :guest      | true | true | false
          :planner    | true | true | false
          :reporter   | true | true | false
          :developer  | true | true | false
          :maintainer | false | true | true
          :maintainer | false | false | true
          :maintainer | true | true   | true
          :maintainer | true | false | true
          :owner      | false  | true | true
          :owner      | false  | false | true
          :owner      | true   | false | true
          :owner      | true   | true | true
          :admin      | false  | true | true
          :admin      | true | false | true
        end

        with_them do
          let(:current_user) { public_send(role) }

          before do
            stub_licensed_features(disable_invite_members: false)
            stub_application_setting(app_setting => application_setting)
            allow(project.group).to receive(:disable_invite_members?).and_return(parent_group_setting)
            enable_admin_mode!(current_user) if role == :admin
          end

          it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
        end
      end
    end

    context 'with disable_invite_members available in license' do
      where(:role, :setting, :admin_mode, :allowed) do
        :guest      | true  | nil    | false
        :planner    | true  | nil    | false
        :reporter   | true  | nil    | false
        :developer  | true  | nil    | false
        :maintainer | false | nil    | true
        :maintainer | true  | nil    | false
        :owner      | false | nil    | true
        :owner      | true  | nil    | false
        :admin      | false | false  | false
        :admin      | false | true   | true
        :admin      | true  | false  | false
      end

      with_them do
        let(:current_user) { public_send(role) }

        before do
          stub_licensed_features(disable_invite_members: true)
          stub_application_setting(app_setting => setting)
          enable_admin_mode!(current_user) if admin_mode
        end

        it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
      end
    end

    context 'with disable_invite_members not available in license' do
      where(:role, :setting, :admin_mode, :allowed) do
        :guest      | true  | nil    | false
        :planner    | true  | nil    | false
        :reporter   | true  | nil    | false
        :developer  | true  | nil    | false
        :maintainer | false | nil    | true
        :maintainer | true  | nil    | true
        :owner      | false | nil    | true
        :owner      | true  | nil    | true
        :admin      | false | false  | false
        :admin      | false | true   | true
        :admin      | true  | false  | false
        :admin      | true  | true   | true
      end

      with_them do
        let(:current_user) { public_send(role) }

        before do
          stub_licensed_features(disable_invite_members: false)
          stub_application_setting(app_setting => setting)
          enable_admin_mode!(current_user) if admin_mode
        end

        it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
      end
    end
  end

  describe 'pages_multiple_versions_available' do
    let(:current_user) { maintainer }

    before do
      stub_licensed_features(pages_multiple_versions: licensed)
    end

    context 'when pages_multiple_versions feature is available' do
      let(:licensed) { true }

      it 'allows access to pages multiple deployments' do
        is_expected.to allow_action(:pages_multiple_versions)
      end
    end

    context 'when pages_multiple_versions feature is not available' do
      let(:licensed) { false }

      it 'denies access to pages multiple deployments' do
        is_expected.not_to allow_action(:pages_multiple_versions)
      end
    end
  end

  describe 'create_epic' do
    where(:current_user, :match_role_permissions) do
      ref(:owner)      | be_allowed(:create_epic)
      ref(:maintainer) | be_allowed(:create_epic)
      ref(:developer)  | be_allowed(:create_epic)
      ref(:reporter)   | be_allowed(:create_epic)
      ref(:planner)    | be_allowed(:create_epic)
      ref(:guest)      | be_disallowed(:create_epic)
      ref(:non_member) | be_disallowed(:create_epic)
    end

    with_them do
      context 'when epics feature is available' do
        before do
          stub_licensed_features(epics: true)
        end

        it { is_expected.to match_role_permissions }

        context 'when project_work_item_epics feature flag is disabled' do
          before do
            stub_feature_flags(project_work_item_epics: false)
          end

          it { is_expected.to be_disallowed(:create_epic) }
        end

        context 'when issues are disabled for the project' do
          before do
            project.update!(issues_enabled: false)
          end

          it { is_expected.to be_disallowed(:create_epic) }
        end
      end

      context 'when epic feature is not available' do
        before do
          stub_licensed_features(epics: false)
        end

        it { is_expected.to be_disallowed(:create_epic) }
      end
    end
  end

  describe 'access_description_composer' do
    let(:authorizer) { instance_double(::Gitlab::Llm::FeatureAuthorizer) }
    let(:current_user) { can_read_mr ? reporter : nil }

    where(:duo_features_enabled, :feature_flag_enabled, :llm_authorized, :can_read_mr, :expected_result) do
      true  | true  | true  | true  | be_allowed(:access_description_composer)
      true  | true  | true  | false | be_disallowed(:access_description_composer)
      true  | false | true  | true  | be_disallowed(:access_description_composer)
      true  | true  | false | true  | be_disallowed(:access_description_composer)
      false | true  | true  | true  | be_disallowed(:access_description_composer)
    end

    with_them do
      before do
        allow(project)
          .to receive_message_chain(:project_setting, :duo_features_enabled?)
          .and_return(duo_features_enabled)

        stub_feature_flags(mr_description_composer: feature_flag_enabled)

        if current_user
          allow(::Gitlab::Llm::FeatureAuthorizer).to receive(:new).and_return(authorizer)
          allow(authorizer).to receive(:allowed?).and_return(llm_authorized)
        end
      end

      it { is_expected.to expected_result }
    end
  end

  describe 'access_duo_agentic_chat' do
    let_it_be(:current_user) { create(:user) }
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }

    subject { described_class.new(current_user, project) }

    context 'when on SaaS instance', :saas do
      include_context 'with duo pro addon'

      where(
        :duo_agentic_chat_enabled,
        :agentic_chat_allowed,
        :has_pinned_duo_chat_model,
        :amazon_q_enabled,
        :duo_agentic_chat_matcher
      ) do
        true  | true  | false | false | be_allowed(:access_duo_agentic_chat)
        true  | true  | false | true  | be_disallowed(:access_duo_agentic_chat)
        true  | false | false | false | be_disallowed(:access_duo_agentic_chat)
        false | false | false | false | be_disallowed(:access_duo_agentic_chat)
        false | true  | false | false | be_disallowed(:access_duo_agentic_chat)
        true  | true  | true  | false | be_disallowed(:access_duo_agentic_chat)
        true  | false | true  | false | be_disallowed(:access_duo_agentic_chat)
        false | false | true  | false | be_disallowed(:access_duo_agentic_chat)
        false | true  | true  | false | be_disallowed(:access_duo_agentic_chat)
      end

      with_them do
        before do
          stub_feature_flags(duo_agentic_chat: duo_agentic_chat_enabled)
          allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(group, :agentic_chat).and_return(agentic_chat_allowed)
          allow(Ai::ModelSelection::NamespaceFeatureSetting).to receive(:any_non_default_for_duo_chat?).and_return(has_pinned_duo_chat_model)
          allow(::Ai::AmazonQ).to receive(:enabled?).and_return(amazon_q_enabled)
        end

        it { is_expected.to duo_agentic_chat_matcher }
      end
    end
  end

  describe 'project secrets permissions' do
    where(:project_visibility, :secrets_manager_active, :role, :allowed) do
      :private  | false | :guest      | false
      :private  | false | :reporter   | false
      :private  | false | :owner      | false
      :private  | true  | :anonymous  | false
      :private  | true  | :guest      | false
      :private  | true  | :reporter   | true
      :private  | true  | :owner      | true
      :private  | true  | :guest      | false
      :private  | true  | :reporter   | true
      :private  | true  | :developer  | true
      :private  | true  | :owner      | true
      :public   | true  | :anonymous  | false
      :public   | true  | :reporter   | true
    end

    with_them do
      let(:project) { create(:project, project_visibility) }
      let!(:secrets_manager) do
        if secrets_manager_active
          secrets_manager_active_value = secrets_manager_active ? 1 : 0
          create(:project_secrets_manager, project: project, status: secrets_manager_active_value)
        end
      end

      let(:current_user) do
        case role
        when :anonymous
          anonymous
        when :guest
          create(:user, guest_of: project)
        when :reporter
          create(:user, reporter_of: project)
        when :developer
          create(:user, developer_of: project)
        when :maintainer
          create(:user, maintainer_of: project)
        when :owner
          create(:user, owner_of: project)
        else
          public_send(role)
        end
      end

      it "enforces the expected permissions" do
        %i[read_project_secrets create_project_secrets update_project_secrets delete_project_secrets].each do |permission|
          if allowed
            is_expected.to be_allowed(permission)
          else
            is_expected.to be_disallowed(permission)
          end
        end
      end
    end
  end

  describe 'secrets_manager_status permissions' do
    let(:policy) { :read_project_secrets_manager_status }

    where(:project_visibility, :secrets_manager_active, :role, :allowed) do
      :private  | false | :guest      | false
      :private  | false | :reporter   | true
      :private  | false | :owner      | true
      :private  | true  | :anonymous  | false
      :private  | true  | :guest      | false
      :private  | true  | :reporter   | true
      :private  | true  | :owner      | true
      :private  | true  | :guest      | false
      :private  | true  | :reporter   | true
      :private  | true  | :developer  | true
      :private  | true  | :owner      | true
      :public   | true  | :anonymous  | false
      :public   | true  | :reporter   | true
    end

    with_them do
      let(:project) { create(:project, project_visibility) }
      let!(:secrets_manager) do
        if secrets_manager_active
          secrets_manager_active_value = secrets_manager_active ? 1 : 0
          create(:project_secrets_manager, project: project, status: secrets_manager_active_value)
        end
      end

      let(:current_user) do
        case role
        when :anonymous
          anonymous
        when :guest
          create(:user, guest_of: project)
        when :reporter
          create(:user, reporter_of: project)
        when :developer
          create(:user, developer_of: project)
        when :maintainer
          create(:user, maintainer_of: project)
        when :owner
          create(:user, owner_of: project)
        else
          public_send(role)
        end
      end

      it "enforces the expected permissions" do
        if allowed
          is_expected.to be_allowed(policy)
        else
          is_expected.to be_disallowed(policy)
        end
      end
    end
  end

  describe 'AI catalog abilities' do
    let(:current_user) { maintainer }

    context 'with global_ai_catalog feature flag enabled' do
      context 'when maintainer' do
        it { is_expected.to be_allowed(:admin_ai_catalog_item) }
        it { is_expected.to be_allowed(:admin_ai_catalog_item_consumer) }
      end

      context 'when developer' do
        let(:current_user) { developer }

        it { is_expected.to be_disallowed(:admin_ai_catalog_item) }
        it { is_expected.to be_disallowed(:admin_ai_catalog_item_consumer) }
        it { is_expected.to be_allowed(:read_ai_catalog_item_consumer) }
      end

      context 'when reporter' do
        let(:current_user) { reporter }

        it { is_expected.to be_disallowed(:read_ai_catalog_item_consumer) }
      end
    end

    context 'when global_ai_catalog feature flag is disabled' do
      before do
        stub_feature_flags(global_ai_catalog: false)
      end

      it { is_expected.to be_disallowed(:admin_ai_catalog_item) }
      it { is_expected.to be_disallowed(:admin_ai_catalog_item_consumer) }
      it { is_expected.to be_disallowed(:read_ai_catalog_item_consumer) }
    end
  end

  context 'deploy token access' do
    subject { described_class.new(deploy_token, project) }

    context 'private project' do
      let(:project) { private_project }

      context 'a deploy token with read_registry scope' do
        let(:deploy_token) { create(:deploy_token, read_registry: true, write_registry: false, projects: [project]) }

        context 'with registry disabled' do
          include_context 'registry disabled via project features'

          it { is_expected.to be_disallowed(:create_container_registry_protection_immutable_tag_rule) }
        end
      end
    end
  end

  describe 'creating container registry protection immutable tag rules' do
    using RSpec::Parameterized::TableSyntax

    where(:user_role, :expected_result) do
      :admin      | :be_allowed
      :owner      | :be_allowed
      :maintainer | :be_disallowed
      :developer  | :be_disallowed
      :reporter   | :be_disallowed
      :planner    | :be_disallowed
      :guest      | :be_disallowed
      :anonymous  | :be_disallowed
    end

    with_them do
      let(:current_user) do
        public_send(user_role)
      end

      before do
        enable_admin_mode!(current_user) if user_role == :admin
      end

      it { is_expected.to send(expected_result, :create_container_registry_protection_immutable_tag_rule) }
    end
  end
end
