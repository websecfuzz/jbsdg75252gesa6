# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Groups, :with_current_organization, :aggregate_failures, feature_category: :groups_and_projects do
  include GroupAPIHelpers

  let_it_be(:ssh_certificate_1) { create(:group_ssh_certificate) }
  let_it_be(:ssh_certificate_2) { create(:group_ssh_certificate) }
  let_it_be(:group, reload: true) { create(:group, ssh_certificates: [ssh_certificate_1, ssh_certificate_2]) }
  let_it_be(:private_group) { create(:group, :private) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user, organizations: [current_organization]) }
  let_it_be(:another_user) { create(:user, organizations: [current_organization]) }
  let_it_be(:admin) { create(:admin, organizations: [current_organization]) }

  before do
    group.add_owner(user)
    group.ldap_group_links.create! cn: 'ldap-group', group_access: Gitlab::Access::MAINTAINER, provider: 'ldap'
    group.saml_group_links.create! saml_group_name: 'saml-group', access_level: Gitlab::Access::GUEST
  end

  shared_examples 'inaccessable by reporter role and lower' do
    context 'for reporter' do
      before do
        reporter = create(:user)
        group.add_reporter(reporter)

        get api(path, reporter)
      end

      it 'returns 403 response' do
        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'for guest' do
      before do
        guest = create(:user)
        group.add_guest(guest)

        get api(path, guest)
      end

      it 'returns 403 response' do
        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'for anonymous' do
      before do
        anonymous = create(:user)

        get api(path, anonymous)
      end

      it 'returns 403 response' do
        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe "GET /groups" do
    context "when authenticated as user" do
      it "returns ldap details" do
        get api("/groups", user)

        expect(json_response).to(
          satisfy_one { |group_json| group_json['ldap_cn'] == group.ldap_cn })
        expect(json_response).to(
          satisfy_one do |group_json|
            group_json['ldap_access'] == group.ldap_access
          end
        )

        expect(json_response).to(
          satisfy_one do |group_json|
            ldap_group_link = group_json['ldap_group_links'].first

            ldap_group_link['cn'] == group.ldap_cn &&
              ldap_group_link['group_access'] == group.ldap_access &&
              ldap_group_link['provider'] == 'ldap'
          end
        )
      end

      it "returns saml group links" do
        get api("/groups", user)

        expect(json_response).to(
          satisfy_one do |group_json|
            saml_group_link = group_json['saml_group_links'].first

            saml_group_link['name'] == 'saml-group' &&
            saml_group_link['access_level'] == ::Gitlab::Access::GUEST
          end
        )
      end

      context 'when repository storage name is specified' do
        let_it_be(:group_with_wiki) { create(:group, :wiki_repo) }
        let_it_be(:group_without_wiki) { create(:group) }
        let_it_be(:storage) { group_with_wiki.repository_storage }

        context 'for an admin' do
          it 'filters by the repository storage name' do
            stub_licensed_features(group_wikis: true)

            get api("/groups", admin, admin_mode: true), params: { repository_storage: storage }

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response.size).to eq(1)
            expect(json_response.first['repository_storage']).to eq(storage)
          end

          context 'when group wikis are not available' do
            it 'does not include repository storage field' do
              get api("/groups", admin, admin_mode: true), params: { repository_storage: storage }

              expect(response).to have_gitlab_http_status(:ok)
              expect(json_response.size).to eq(1)
              expect(json_response.first).not_to have_key('repository_storage')
            end
          end

          it 'does not return any group for unknown storage' do
            get api("/groups", admin, admin_mode: true), params: { repository_storage: "#{storage}-unknown" }

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response.size).to eq(0)
          end
        end

        context 'for a user' do
          before do
            group_with_wiki.add_developer(user)
            group_without_wiki.add_developer(user)
          end

          it 'the repository storage filter is ignored' do
            get api("/groups", user), params: { repository_storage: storage }

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response.size).to eq(3)
            expect(json_response).to all exclude('repository_storage')
          end
        end
      end
    end
  end

  describe 'GET /groups/:id' do
    context 'group_ip_restriction' do
      before do
        create(:ip_restriction, group: private_group)
        private_group.add_maintainer(user)
      end

      context 'when the group_ip_restriction feature is not available' do
        before do
          stub_licensed_features(group_ip_restriction: false)
        end

        it 'returns 200' do
          get api("/groups/#{private_group.id}", user)

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'when the group_ip_restriction feature is available' do
        before do
          stub_licensed_features(group_ip_restriction: true)
        end

        it 'returns 404 for request from ip not in the range' do
          get api("/groups/#{private_group.id}", user)

          expect(response).to have_gitlab_http_status(:not_found)
        end

        it 'returns 200 for request from ip in the range' do
          get api("/groups/#{private_group.id}", user), headers: { 'REMOTE_ADDR' => '192.168.0.0' }

          expect(response).to have_gitlab_http_status(:ok)
        end
      end
    end

    context 'file_template_project_id is a private project' do
      let_it_be(:private_project) { create(:project, :private, group: group) }

      before do
        stub_licensed_features(custom_file_templates_for_namespace: true)
        group.update_attribute(:file_template_project_id, private_project.id)
      end

      context 'user has permission to private project' do
        it 'returns file_template_project_id' do
          private_project.add_maintainer(user)

          get api("/groups/#{group.id}", user)

          expect(json_response).to have_key 'file_template_project_id'
        end
      end

      context 'user does not have permission to private project' do
        it 'does not return file_template_project_id' do
          get api("/groups/#{group.id}", another_user)

          expect(json_response).not_to have_key 'file_template_project_id'
        end
      end

      context 'user is not logged in' do
        it 'does not return file_template_project_id' do
          get api("/groups/#{group.id}")

          expect(json_response).not_to have_key 'file_template_project_id'
        end
      end
    end
  end

  describe 'PUT /groups/:id' do
    let_it_be(:admin_mode) { false }

    subject(:update_group_request) { put api("/groups/#{group.id}", user, admin_mode: admin_mode), params: params }

    it_behaves_like 'PUT request permissions for admin mode' do
      let(:path) { "/groups/#{group.id}" }
      let(:params) { { default_branch_protection: Gitlab::Access::PROTECTION_NONE } }
    end

    context 'file_template_project_id' do
      let(:params) { { file_template_project_id: project.id } }

      it 'does not update file_template_project_id if unlicensed' do
        stub_licensed_features(custom_file_templates_for_namespace: false)

        expect { subject }.not_to change { group.reload.file_template_project_id }
        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).not_to have_key('file_template_project_id')
      end

      it 'updates file_template_project_id if licensed' do
        stub_licensed_features(custom_file_templates_for_namespace: true)

        expect { subject }.to change { group.reload.file_template_project_id }.to(project.id)
        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['file_template_project_id']).to eq(project.id)
      end
    end

    context 'shared_runners_minutes_limit' do
      let(:params) { { shared_runners_minutes_limit: 133 } }

      context 'when authenticated as the group owner' do
        it 'returns 200 if shared_runners_minutes_limit is not changing' do
          group.update!(shared_runners_minutes_limit: 133)

          expect do
            put api("/groups/#{group.id}", user), params: { shared_runners_minutes_limit: 133 }
          end.not_to change { group.shared_runners_minutes_limit }

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'when authenticated as the admin' do
        let(:user) { create(:admin) }

        it 'updates the group for shared_runners_minutes_limit' do
          expect { subject }.to(
            change { group.reload.shared_runners_minutes_limit }.from(nil).to(133))

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['shared_runners_minutes_limit']).to eq(133)
        end
      end
    end

    context 'default_branch_protection' do
      using RSpec::Parameterized::TableSyntax

      let(:params) { { default_branch_protection: Gitlab::Access::PROTECTION_NONE } }

      context 'authenticated as an admin' do
        let(:user) { admin }
        let_it_be(:admin_mode) { true }

        where(:feature_enabled, :setting_enabled, :default_branch_protection) do
          true  | true  | Gitlab::Access::PROTECTION_NONE
          false | true  | Gitlab::Access::PROTECTION_NONE
          true  | false | Gitlab::Access::PROTECTION_NONE
          false | false | Gitlab::Access::PROTECTION_NONE
        end

        with_them do
          before do
            stub_licensed_features(default_branch_protection_restriction_in_groups: feature_enabled)
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: setting_enabled)
          end

          it 'updates the attribute as expected' do
            subject

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['default_branch_protection']).to eq(default_branch_protection)
          end
        end
      end

      context 'authenticated a normal user' do
        where(:feature_enabled, :setting_enabled, :default_branch_protection) do
          true  | true  | Gitlab::Access::PROTECTION_NONE
          false | true  | Gitlab::Access::PROTECTION_NONE
          true  | false | Gitlab::Access::PROTECTION_FULL
          false | false | Gitlab::Access::PROTECTION_NONE
        end

        with_them do
          before do
            stub_licensed_features(default_branch_protection_restriction_in_groups: feature_enabled)
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: setting_enabled)
          end

          it 'updates the attribute as expected' do
            subject

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['default_branch_protection']).to eq(default_branch_protection)
          end
        end
      end
    end

    context 'service_access_tokens_expiration_enforced' do
      using RSpec::Parameterized::TableSyntax

      context 'authenticated as group owner' do
        where(:feature_enabled, :service_access_tokens_expiration_enforced, :result) do
          false | false | nil
          false | true  | nil
          true  | false | false
          true  | true  | true
        end

        with_them do
          let(:params) { { service_access_tokens_expiration_enforced: service_access_tokens_expiration_enforced } }

          before do
            group.add_owner(user)

            stub_licensed_features(service_accounts: feature_enabled)
          end

          it 'updates the attribute as expected' do
            subject

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['service_access_tokens_expiration_enforced']).to eq(result)
          end
        end
      end
    end

    context 'prevent_forking_outside_group' do
      using RSpec::Parameterized::TableSyntax

      context 'authenticated as group owner' do
        where(:feature_enabled, :prevent_forking_outside_group, :result) do
          false | false | nil
          false | true  | nil
          true  | false | false
          true  | true  | true
        end

        with_them do
          let(:params) { { prevent_forking_outside_group: prevent_forking_outside_group } }

          before do
            group.add_owner(user)

            stub_licensed_features(group_forking_protection: feature_enabled)
          end

          it 'updates the attribute as expected' do
            subject

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['prevent_forking_outside_group']).to eq(result)
          end
        end
      end
    end

    context 'when allowed_email_domains_list is specified' do
      let(:params) { { allowed_email_domains_list: "example.com,example.org" } }

      context "when feature is available" do
        before do
          stub_licensed_features(group_allowed_email_domains: true)
        end

        it 'updates email domain allowlist for the group' do
          expect { subject }.to change { group.reload.allowed_email_domains_list }
          .to("example.com,example.org")
          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['allowed_email_domains_list']).to eq("example.com,example.org")
        end

        context 'when user is a maintainer' do
          let_it_be(:user) { create(:user) }

          before do
            group.add_maintainer(user)
          end

          it 'does not update the email domain allow list for the group' do
            expect { subject }.not_to change { group.reload.allowed_email_domains_list }
            expect(response).to have_gitlab_http_status(:forbidden)
            expect(json_response['allowed_email_domains_list']).to be_nil
          end
        end
      end

      context "when feature is not available" do
        it 'does not update the email domain allowlist for the group' do
          expect { subject }.not_to change { group.reload.allowed_email_domains_list }
          expect(json_response).not_to have_key 'allowed_email_domains_list'
        end
      end
    end

    context 'when ip_restriction_ranges is specified' do
      let(:params) { { ip_restriction_ranges: "192.168.0.0/24,10.0.0.0/8" } }

      context "when feature is available" do
        before do
          stub_licensed_features(group_ip_restriction: true)
        end

        it 'updates ip restriction range for the group' do
          expect { subject }.to change { group.reload.ip_restriction_ranges }.to("192.168.0.0/24,10.0.0.0/8")
          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['ip_restriction_ranges']).to eq("192.168.0.0/24,10.0.0.0/8")
        end
      end

      context "when feature is not available" do
        it 'does not update the ip restriction range for the group' do
          expect { subject }.not_to change { group.reload.ip_restriction_ranges }
          expect(json_response).not_to have_key 'ip_restriction_ranges'
        end

        context 'for instances that have the usage_ping_features activated' do
          before do
            stub_application_setting(usage_ping_enabled: true)
            stub_application_setting(usage_ping_features_enabled: true)
          end

          it 'updates ip restriction range for the group' do
            expect { subject }.to change { group.reload.ip_restriction_ranges }.to("192.168.0.0/24,10.0.0.0/8")
            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['ip_restriction_ranges']).to eq("192.168.0.0/24,10.0.0.0/8")
          end
        end
      end
    end

    describe 'unique_project_download* attributes', feature_category: :insider_threat do
      context 'when authenticated as group owner' do
        let(:allowed_username) { create(:user).username }
        let(:alerted_user_id) { create(:user).id }
        let(:params) do
          {
            unique_project_download_limit: 1,
            unique_project_download_limit_interval_in_seconds: 2,
            unique_project_download_limit_allowlist: [allowed_username],
            unique_project_download_limit_alertlist: [alerted_user_id],
            auto_ban_user_on_excessive_projects_download: true
          }
        end

        before do
          stub_licensed_features(unique_project_download_limit: feature_available)
          group.add_owner(user)
          subject
        end

        context 'when feature is available' do
          let(:feature_available) { true }

          it 'updates the attributes as expected' do
            settings = group.namespace_settings.reload

            expect(response).to have_gitlab_http_status(:ok)
            expect(settings.unique_project_download_limit).to eq 1
            expect(settings.unique_project_download_limit_interval_in_seconds).to eq 2
            expect(settings.unique_project_download_limit_allowlist).to contain_exactly(allowed_username)
            expect(settings.unique_project_download_limit_alertlist).to contain_exactly(alerted_user_id)
            expect(settings.auto_ban_user_on_excessive_projects_download).to eq true
          end
        end

        context 'when feature is not available' do
          let(:feature_available) { false }

          it 'does not update the attributes' do
            settings = group.namespace_settings.reload

            expect(response).to have_gitlab_http_status(:ok)
            expect(settings.unique_project_download_limit).to eq 0
            expect(settings.unique_project_download_limit_interval_in_seconds).to eq 0
            expect(settings.unique_project_download_limit_allowlist).to be_empty
            expect(settings[:unique_project_download_limit_alertlist]).to be_empty
            expect(settings.auto_ban_user_on_excessive_projects_download).to eq false
          end
        end
      end
    end

    context 'wiki_access_level' do
      %w[disabled private enabled].each do |access_level|
        it 'updates the attribute as expected' do
          put api("/groups/#{group.id}", user), params: { wiki_access_level: access_level }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['wiki_access_level']).to eq(access_level)
        end
      end
    end

    context 'duo_core_features_enabled' do
      let(:params) { { duo_core_features_enabled: true } }

      before do
        stub_licensed_features(code_suggestions: true)
      end

      context 'authenticated as group owner' do
        using RSpec::Parameterized::TableSyntax

        where(:code_suggestions_enabled, :param_value, :result) do
          false | false | nil
          false | true  | nil
          true  | false | false
          true  | true  | true
        end

        with_them do
          let(:params) { { duo_core_features_enabled: param_value } }

          before do
            stub_licensed_features(code_suggestions: code_suggestions_enabled)
          end

          it 'updates the attribute and exposes the field as expected' do
            update_group_request

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['duo_core_features_enabled']).to eq(result)
          end
        end

        context 'when the group is not a top-level group namespace' do
          let(:group) { create(:group, :nested) }

          it 'doest not allow update and returns bad request' do
            update_group_request

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response["message"].values.flatten.to_sentence).to match(/can only be set for root group namespace/)
          end
        end

        context 'when updating already toggled value to nil' do
          let(:params) { { duo_core_features_enabled: nil } }

          before do
            group.namespace_settings.update!(duo_core_features_enabled: true)
          end

          it 'doest not allow update and returns bad request' do
            update_group_request

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response["message"].values.flatten.to_sentence).to match(/is not included in the list/)
          end
        end
      end

      context 'when the user does not have correct access level to group' do
        before do
          group.members.delete_all
          group.add_maintainer(user)
        end

        it 'doest not allow update and returns forbidden status' do
          update_group_request

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end

    context 'duo_features_enabled' do
      using RSpec::Parameterized::TableSyntax

      context 'authenticated as group owner' do
        where(:feature_enabled, :param, :value, :result) do
          false | 'duo_features_enabled' | false | nil
          false | 'lock_duo_features_enabled' | true | nil
          true | 'duo_features_enabled' | false | false
          true | 'lock_duo_features_enabled' | true | true
        end

        with_them do
          let(:params) { { param => value } }

          before do
            group.add_owner(user)

            stub_licensed_features(ai_features: feature_enabled)
          end

          it 'updates the attribute as expected' do
            subject

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response[param]).to eq(result)
          end
        end
      end
    end

    context 'prevent_sharing_groups_outside_hierarchy' do
      context 'when block seat overages is enabled for the group', :saas do
        before_all do
          create(:gitlab_subscription, :premium, namespace: group)
        end

        before do
          stub_saas_features(gitlab_com_subscriptions: true)
          group.namespace_settings.update!(seat_control: :block_overages)
        end

        it 'will not set prevent_sharing_groups_outside_hierarchy to false' do
          put api("/groups/#{group.id}", user), params: { description: 'it works', prevent_sharing_groups_outside_hierarchy: false }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['description']).to eq('it works')
          expect(json_response['prevent_sharing_groups_outside_hierarchy']).to eq(true)
          expect(group.reload.prevent_sharing_groups_outside_hierarchy).to eq(true)
        end
      end
    end

    context 'amazon_q_auto_review_enabled' do
      let_it_be(:integration) { create(:amazon_q_integration, instance: false, group: group) }

      it 'updates auto_review_enabled field of Amazon Q integration' do
        allow(::Ai::AmazonQ).to receive(:connected?).and_return(true)

        expect do
          put api("/groups/#{group.id}", user), params: { duo_availability: 'default_on', amazon_q_auto_review_enabled: true }
        end.to change { group.amazon_q_integration.reload.auto_review_enabled }.from(false).to(true)

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'duo_workflow_mcp_enabled' do
      it 'updates duo_workflow_mcp_enabled field of namespace AI settings' do
        expect do
          put api("/groups/#{group.id}", user), params: { ai_settings_attributes: { duo_workflow_mcp_enabled: true } }
        end.to change { group.reload.duo_workflow_mcp_enabled }.from(nil).to(true)

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'web_based_commit_signing_enabled' do
      using RSpec::Parameterized::TableSyntax
      context 'when authenticated as group owner' do
        where(:feature_available, :feature_enabled, :result) do
          true  | false | false
          true  | true  | true
          false | true  | nil
          false | false | nil
        end

        with_them do
          let(:params) { { web_based_commit_signing_enabled: true } }

          before do
            group.add_owner(user)

            stub_saas_features(repositories_web_based_commit_signing: feature_available)
            stub_feature_flags(use_web_based_commit_signing_enabled: feature_enabled)
          end

          it 'updates the attribute as expected' do
            subject

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['web_based_commit_signing_enabled']).to eq(result)
          end
        end
      end
    end
  end

  describe "POST /groups" do
    it_behaves_like 'POST request permissions for admin mode' do
      let(:path) { '/groups' }
      let(:params) { attributes_for_group_api shared_runners_minutes_limit: 133 }
    end

    context 'when the top_level_group_creation_enabled application_setting is enabled (default)' do
      it 'creates a top-level group' do
        group_attributes = attributes_for_group_api name: 'top_level_group_1', path: 'top_level_group_1'

        expect { post api("/groups", user), params: group_attributes }
          .to change { Group.count }.by(1)
        expect(response).to have_gitlab_http_status(:created)
      end
    end

    context 'when the top_level_group_creation_enabled application_setting is disabled' do
      before do
        stub_ee_application_setting(top_level_group_creation_enabled: false)
      end

      it 'returns an error' do
        group_attributes = attributes_for_group_api name: 'top_level_group_1', path: 'top_level_group_1'

        expect { post api("/groups", user), params: group_attributes }
          .not_to change { Group.count }
        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context "when authenticated as user with group permissions" do
      it "creates an ldap_group_link if ldap_cn and ldap_access are supplied" do
        group_attributes = attributes_for_group_api ldap_cn: 'ldap-group', ldap_access: Gitlab::Access::DEVELOPER

        expect { post api("/groups", admin), params: group_attributes }.to change { LdapGroupLink.count }.by(1)
      end

      context 'when shared_runners_minutes_limit is given' do
        context 'when the current user is not an admin' do
          it "does not create a group with shared_runners_minutes_limit" do
            group = attributes_for_group_api shared_runners_minutes_limit: 133

            expect do
              post api("/groups", another_user), params: group
            end.not_to change { Group.count }

            expect(response).to have_gitlab_http_status(:forbidden)
          end
        end

        context 'when the current user is an admin' do
          it "creates a group with shared_runners_minutes_limit" do
            group = attributes_for_group_api shared_runners_minutes_limit: 133

            expect do
              post api("/groups", admin, admin_mode: true), params: group
            end.to change { Group.count }.by(1)

            created_group = Group.find(json_response['id'])

            expect(created_group.shared_runners_minutes_limit).to eq(133)
            expect(response).to have_gitlab_http_status(:created)
            expect(json_response['shared_runners_minutes_limit']).to eq(133)
          end
        end
      end
    end

    context 'when creating a group with `default_branch_protection` attribute' do
      using RSpec::Parameterized::TableSyntax

      let(:params) { attributes_for_group_api(default_branch_protection: Gitlab::Access::PROTECTION_NONE) }
      let_it_be(:admin_mode) { false }

      subject do
        post api("/groups", user, admin_mode: admin_mode), params: params
      end

      context 'authenticated as an admin' do
        let(:user) { admin }
        let_it_be(:admin_mode) { true }

        where(:feature_enabled, :setting_enabled, :default_branch_protection) do
          true  | true  | Gitlab::Access::PROTECTION_NONE
          false | true  | Gitlab::Access::PROTECTION_NONE
          true  | false | Gitlab::Access::PROTECTION_NONE
          false | false | Gitlab::Access::PROTECTION_NONE
        end

        with_them do
          before do
            stub_licensed_features(default_branch_protection_restriction_in_groups: feature_enabled)
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: setting_enabled)
          end

          it 'creates the group with the expected `default_branch_protection` value' do
            subject

            expect(response).to have_gitlab_http_status(:created)
            expect(json_response['default_branch_protection']).to eq(default_branch_protection)
          end
        end
      end

      context 'authenticated a normal user' do
        where(:feature_enabled, :setting_enabled, :default_branch_protection) do
          true  | true  | Gitlab::Access::PROTECTION_NONE
          false | true  | Gitlab::Access::PROTECTION_NONE
          true  | false | Gitlab::Access::PROTECTION_FULL
          false | false | Gitlab::Access::PROTECTION_NONE
        end

        with_them do
          before do
            stub_licensed_features(default_branch_protection_restriction_in_groups: feature_enabled)
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: setting_enabled)
          end

          it 'creates the group with the expected `default_branch_protection` value' do
            subject

            expect(response).to have_gitlab_http_status(:created)
            expect(json_response['default_branch_protection']).to eq(default_branch_protection)
          end
        end
      end
    end

    context 'wiki_access_level' do
      %w[disabled private enabled].each do |access_level|
        it 'updates the attribute as expected' do
          post api("/groups", admin), params: attributes_for_group_api.merge(wiki_access_level: access_level)

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['wiki_access_level']).to eq(access_level)
        end
      end
    end
  end

  describe 'POST /groups/:id/ldap_sync' do
    before do
      allow(Gitlab::Auth::Ldap::Config).to receive(:enabled?).and_return(true)
    end

    it_behaves_like 'POST request permissions for admin mode' do
      let(:path) { "/groups/#{group.id}/ldap_sync" }
      let(:params) { {} }
      let(:success_status_code) { :accepted }
    end

    context 'when the ldap_group_sync feature is available' do
      before do
        stub_licensed_features(ldap_group_sync: true)
      end

      context 'when authenticated as the group owner' do
        context 'when the group is ready to sync' do
          it 'returns 202 Accepted' do
            ldap_sync(group.id, user, :disable!)
            expect(response).to have_gitlab_http_status(:accepted)
          end

          it 'queues a sync job' do
            expect { ldap_sync(group.id, user, :fake!) }.to change(LdapGroupSyncWorker.jobs, :size).by(1)
          end

          it 'sets the ldap_sync state to pending' do
            ldap_sync(group.id, user, :disable!)
            expect(group.reload.ldap_sync_pending?).to be_truthy
          end
        end

        context 'when the group is already pending a sync' do
          before do
            group.pending_ldap_sync!
          end

          it 'returns 202 Accepted' do
            ldap_sync(group.id, user, :disable!)
            expect(response).to have_gitlab_http_status(:accepted)
          end

          it 'does not queue a sync job' do
            expect { ldap_sync(group.id, user, :fake!) }.not_to change(LdapGroupSyncWorker.jobs, :size)
          end

          it 'does not change the ldap_sync state' do
            expect do
              ldap_sync(group.id, user, :disable!)
            end.not_to change { group.reload.ldap_sync_status }
          end
        end

        it 'returns 404 for a non existing group' do
          ldap_sync(non_existing_record_id, user, :disable!)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when authenticated as the admin' do
        it 'returns 202 Accepted' do
          ldap_sync(group.id, admin, :disable!, true)
          expect(response).to have_gitlab_http_status(:accepted)
        end
      end

      context 'when authenticated as a non-owner user that can see the group' do
        it 'returns 403' do
          ldap_sync(group.id, another_user, :disable!)
          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'when authenticated as an user that cannot see the group' do
        it 'returns 404' do
          ldap_sync(private_group.id, user, :disable!)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'when the ldap_group_sync feature is not available' do
      before do
        stub_licensed_features(ldap_group_sync: false)
      end

      it 'returns 404 (same as CE would)' do
        ldap_sync(group.id, admin, :disable!, admin_mode: true)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe "GET /groups/:id/projects" do
    context "when authenticated as user" do
      let!(:project_with_security_scans) { create(:project, :with_security_scans, :public, group: group) }
      let!(:project_without_security_scans) { create(:project, :public, group: group) }

      subject { get api("/groups/#{group.id}/projects", user), params: { with_security_reports: true } }

      context 'when security dashboard is enabled for a group', :saas do
        let(:group) { create(:group_with_plan, plan: :ultimate_plan) } # overriding group from parent context

        before do
          stub_licensed_features(security_dashboard: true)
          enable_namespace_license_check!
        end

        it "returns only projects with security scans" do
          subject

          expect(json_response.map { |p| p['id'] }).to contain_exactly(project_with_security_scans.id)
        end
      end

      context 'when security dashboard is disabled for a group' do
        it "returns all projects regardless of the security scans" do
          subject

          # using `include` since other projects may be added to this group from different contexts
          expect(json_response.map { |p| p['id'] }).to include(project_with_security_scans.id, project_without_security_scans.id)
        end
      end
    end

    context 'when namespace license checks are enabled', :saas do
      before do
        enable_namespace_license_check!
      end

      context 'when there are plans and projects' do
        let(:group) { create(:group_with_plan, plan: :ultimate_plan) }

        before do
          subgroup = create(:group, parent: group)
          create(:project, group: group)
          create(:project, group: subgroup)
        end

        it 'only loads plans once' do
          expect_next_found_instance_of(GitlabSubscription) do |subscription|
            expect(subscription).to receive(:hosted_plan).once.and_call_original
          end

          get api("/groups/#{group.id}/projects", user), params: { include_subgroups: true }

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'when there are no projects' do
        let(:group) { create(:group) }

        it 'completes the request without error' do
          get api("/groups/#{group.id}/projects", user), params: { include_subgroups: true }

          expect(response).to have_gitlab_http_status(:ok)
        end
      end
    end
  end

  describe 'GET group/:id/audit_events' do
    let(:path) { "/groups/#{group.id}/audit_events" }

    it_behaves_like 'inaccessable by reporter role and lower'

    it_behaves_like 'GET request permissions for admin mode' do
      let(:path) { "/groups/#{group.id}/audit_events" }
    end

    context 'when authenticated, as a member' do
      before do
        stub_licensed_features(audit_events: true)
        group.add_developer(user)
      end

      context 'when read_audit_events_from_new_tables is disabled' do
        before do
          stub_feature_flags(read_audit_events_from_new_tables: false)
        end

        it 'returns only events authored by current user' do
          group_audit_event = create(:group_audit_event, entity_id: group.id, author_id: user.id)
          create(:group_audit_event, entity_id: group.id, author_id: another_user.id)

          get api(path, user)

          expect_response_contain_exactly(group_audit_event.id)
        end
      end

      context 'when read_audit_events_from_new_tables is enabled' do
        before do
          stub_feature_flags(read_audit_events_from_new_tables: true)
        end

        it 'returns only events authored by current user' do
          group_audit_event = create(:audit_events_group_audit_event, group_id: group.id, author_id: user.id)
          create(:audit_events_group_audit_event, group_id: group.id, author_id: another_user.id)

          get api(path, user)

          expect_response_contain_exactly(group_audit_event.id)
        end
      end
    end

    context 'when authenticated, as a group owner' do
      context 'audit events feature is not available' do
        before do
          stub_licensed_features(audit_events: false)
        end

        it_behaves_like '403 response' do
          let(:request) { get api(path, user) }
        end
      end

      context 'audit events feature is available' do
        before do
          stub_licensed_features(audit_events: true)
        end

        context 'when read_audit_events_from_new_tables is disabled' do
          before do
            stub_feature_flags(read_audit_events_from_new_tables: false)
          end

          let_it_be(:group_audit_event_1) { create(:group_audit_event, created_at: Date.new(2000, 1, 10), entity_id: group.id) }
          let_it_be(:group_audit_event_2) { create(:group_audit_event, created_at: Date.new(2000, 1, 15), entity_id: group.id) }
          let_it_be(:group_audit_event_3) { create(:group_audit_event, created_at: Date.new(2000, 1, 20), entity_id: group.id) }

          it 'returns 200 response' do
            get api(path, user)

            expect(response).to have_gitlab_http_status(:ok)
          end

          it 'includes the correct pagination headers' do
            audit_events_counts = 3

            get api(path, user)

            expect(response).to include_pagination_headers
            expect(response.headers['X-Total']).to eq(audit_events_counts.to_s)
            expect(response.headers['X-Page']).to eq('1')
          end

          it 'does not include audit events of a different group' do
            group = create(:group)
            audit_event = create(:group_audit_event, created_at: Date.new(2000, 1, 20), entity_id: group.id)

            get api(path, user)

            audit_event_ids = json_response.map { |audit_event| audit_event['id'] }

            expect(audit_event_ids).not_to include(audit_event.id)
          end

          context 'parameters' do
            it_behaves_like 'an endpoint with keyset pagination' do
              let(:first_record) { group_audit_event_3 }
              let(:second_record) { group_audit_event_2 }
              let(:api_call) { api(path, admin, admin_mode: true) }
            end

            context 'created_before parameter' do
              it "returns audit events created before the given parameter" do
                created_before = '2000-01-20T00:00:00.060Z'

                get api(path, user), params: { created_before: created_before }

                expect(json_response.size).to eq 3
                expect(json_response.first["id"]).to eq(group_audit_event_3.id)
                expect(json_response.last["id"]).to eq(group_audit_event_1.id)
              end
            end

            context 'created_after parameter' do
              it "returns audit events created after the given parameter" do
                created_after = '2000-01-12T00:00:00.060Z'

                get api(path, user), params: { created_after: created_after }

                expect(json_response.size).to eq 2
                expect(json_response.first["id"]).to eq(group_audit_event_3.id)
                expect(json_response.last["id"]).to eq(group_audit_event_2.id)
              end
            end
          end

          context 'response schema' do
            it 'matches the response schema' do
              get api(path, user)

              expect(response).to match_response_schema('public_api/v4/audit_events', dir: 'ee')
            end
          end

          context 'Snowplow event tracking' do
            it_behaves_like 'Snowplow event tracking with RedisHLL context' do
              subject(:api_request) { get api(path, user) }

              let(:category) { 'EE::API::Groups' }
              let(:action) { 'group_audit_event_request' }
              let(:project) { nil }
              let(:namespace) { group }
              let(:context) { [::Gitlab::Tracking::ServicePingContext.new(data_source: :redis_hll, event: 'a_compliance_audit_events_api').to_context] }
            end
          end
        end

        context 'when read_audit_events_from_new_tables is enabled' do
          before do
            stub_feature_flags(read_audit_events_from_new_tables: true)
          end

          let_it_be(:group_audit_event_1) { create(:audit_events_group_audit_event, created_at: Date.new(2000, 1, 10), group_id: group.id) }
          let_it_be(:group_audit_event_2) { create(:audit_events_group_audit_event, created_at: Date.new(2000, 1, 15), group_id: group.id) }
          let_it_be(:group_audit_event_3) { create(:audit_events_group_audit_event, created_at: Date.new(2000, 1, 20), group_id: group.id) }

          it 'returns 200 response' do
            get api(path, user)

            expect(response).to have_gitlab_http_status(:ok)
          end

          it 'includes the correct pagination headers' do
            audit_events_counts = 3

            get api(path, user)

            expect(response).to include_pagination_headers
            expect(response.headers['X-Total']).to eq(audit_events_counts.to_s)
            expect(response.headers['X-Page']).to eq('1')
          end

          it 'does not include audit events of a different group' do
            group = create(:group)
            audit_event = create(:audit_events_group_audit_event, created_at: Date.new(2000, 1, 20), group_id: group.id)

            get api(path, user)

            audit_event_ids = json_response.map { |audit_event| audit_event['id'] }

            expect(audit_event_ids).not_to include(audit_event.id)
          end

          context 'parameters' do
            it_behaves_like 'an endpoint with keyset pagination' do
              let(:first_record) { group_audit_event_3 }
              let(:second_record) { group_audit_event_2 }
              let(:api_call) { api(path, admin, admin_mode: true) }
            end

            context 'created_before parameter' do
              it "returns audit events created before the given parameter" do
                created_before = '2000-01-20T00:00:00.060Z'

                get api(path, user), params: { created_before: created_before }

                expect(json_response.size).to eq 3
                expect(json_response.first["id"]).to eq(group_audit_event_3.id)
                expect(json_response.last["id"]).to eq(group_audit_event_1.id)
              end
            end

            context 'created_after parameter' do
              it "returns audit events created after the given parameter" do
                created_after = '2000-01-12T00:00:00.060Z'

                get api(path, user), params: { created_after: created_after }

                expect(json_response.size).to eq 2
                expect(json_response.first["id"]).to eq(group_audit_event_3.id)
                expect(json_response.last["id"]).to eq(group_audit_event_2.id)
              end
            end
          end

          context 'response schema' do
            it 'matches the response schema' do
              get api(path, user)

              expect(response).to match_response_schema('public_api/v4/audit_events', dir: 'ee')
            end
          end

          context 'Snowplow event tracking' do
            it_behaves_like 'Snowplow event tracking with RedisHLL context' do
              subject(:api_request) { get api(path, user) }

              let(:category) { 'EE::API::Groups' }
              let(:action) { 'group_audit_event_request' }
              let(:project) { nil }
              let(:namespace) { group }
              let(:context) { [::Gitlab::Tracking::ServicePingContext.new(data_source: :redis_hll, event: 'a_compliance_audit_events_api').to_context] }
            end
          end
        end
      end
    end
  end

  describe 'GET group/:id/audit_events/:audit_event_id' do
    let(:path) { "/groups/#{group.id}/audit_events/#{group_audit_event.id}" }

    context 'when read_audit_events_from_new_tables is disabled' do
      before do
        stub_feature_flags(read_audit_events_from_new_tables: false)
      end

      let_it_be(:group_audit_event) { create(:group_audit_event, created_at: Date.new(2000, 1, 10), entity_id: group.id) }

      it_behaves_like 'inaccessable by reporter role and lower'

      context 'when authenticated, as a member' do
        let_it_be(:developer) { create(:user) }

        before do
          stub_licensed_features(audit_events: true)
          group.add_developer(developer)
        end

        it 'returns 200 response' do
          audit_event = create(:group_audit_event, entity_id: group.id, author_id: developer.id)
          path = "/groups/#{group.id}/audit_events/#{audit_event.id}"

          get api(path, developer)

          expect(response).to have_gitlab_http_status(:ok)
        end

        context 'existing audit event of a different user' do
          let_it_be(:audit_event) { create(:group_audit_event, entity_id: group.id, author_id: another_user.id) }

          let(:path) { "/groups/#{group.id}/audit_events/#{audit_event.id}" }

          it_behaves_like '404 response' do
            let(:request) { get api(path, developer) }
          end
        end
      end

      context 'when authenticated, as a group owner' do
        context 'audit events feature is not available' do
          before do
            stub_licensed_features(audit_events: false)
          end

          it_behaves_like '403 response' do
            let(:request) { get api(path, user) }
          end
        end

        context 'audit events feature is available' do
          before do
            stub_licensed_features(audit_events: true)
          end

          context 'existent audit event' do
            it 'returns 200 response' do
              get api(path, user)

              expect(response).to have_gitlab_http_status(:ok)
            end

            context 'response schema' do
              it 'matches the response schema' do
                get api(path, user)

                expect(response).to match_response_schema('public_api/v4/audit_event', dir: 'ee')
              end
            end

            context 'Snowplow event tracking' do
              it_behaves_like 'Snowplow event tracking with RedisHLL context' do
                subject(:api_request) { get api(path, user) }

                let(:category) { 'EE::API::Groups' }
                let(:action) { 'group_audit_event_request' }
                let(:project) { nil }
                let(:namespace) { group }
                let(:context) { [::Gitlab::Tracking::ServicePingContext.new(data_source: :redis_hll, event: 'a_compliance_audit_events_api').to_context] }
              end
            end

            context 'invalid audit_event_id' do
              let(:path) { "/groups/#{group.id}/audit_events/an-invalid-id" }

              it_behaves_like '400 response' do
                let(:request) { get api(path, user) }
              end
            end

            context 'non existent audit event' do
              context 'non existent audit event of a group' do
                let(:path) { "/groups/#{group.id}/audit_events/666777" }

                it_behaves_like '404 response' do
                  let(:request) { get api(path, user) }
                end
              end

              context 'existing audit event of a different group' do
                let(:new_group) { create(:group) }
                let(:audit_event) { create(:group_audit_event, created_at: Date.new(2000, 1, 10), entity_id: new_group.id) }

                let(:path) { "/groups/#{group.id}/audit_events/#{audit_event.id}" }

                it_behaves_like '404 response' do
                  let(:request) { get api(path, user) }
                end
              end
            end
          end
        end
      end
    end

    context 'when read_audit_events_from_new_tables is enabled' do
      before do
        stub_feature_flags(read_audit_events_from_new_tables: true)
      end

      let_it_be(:group_audit_event) { create(:audit_events_group_audit_event, created_at: Date.new(2000, 1, 10), group_id: group.id) }

      it_behaves_like 'inaccessable by reporter role and lower'

      context 'when authenticated, as a member' do
        let_it_be(:developer) { create(:user) }

        before do
          stub_licensed_features(audit_events: true)
          group.add_developer(developer)
        end

        it 'returns 200 response' do
          audit_event = create(:audit_events_group_audit_event, group_id: group.id, author_id: developer.id)
          path = "/groups/#{group.id}/audit_events/#{audit_event.id}"

          get api(path, developer)

          expect(response).to have_gitlab_http_status(:ok)
        end

        context 'existing audit event of a different user' do
          let_it_be(:audit_event) { create(:audit_events_group_audit_event, group_id: group.id, author_id: another_user.id) }

          let(:path) { "/groups/#{group.id}/audit_events/#{audit_event.id}" }

          it_behaves_like '404 response' do
            let(:request) { get api(path, developer) }
          end
        end
      end

      context 'when authenticated, as a group owner' do
        context 'audit events feature is not available' do
          before do
            stub_licensed_features(audit_events: false)
          end

          it_behaves_like '403 response' do
            let(:request) { get api(path, user) }
          end
        end

        context 'audit events feature is available' do
          before do
            stub_licensed_features(audit_events: true)
          end

          context 'existent audit event' do
            it 'returns 200 response' do
              get api(path, user)

              expect(response).to have_gitlab_http_status(:ok)
            end

            context 'response schema' do
              it 'matches the response schema' do
                get api(path, user)

                expect(response).to match_response_schema('public_api/v4/audit_event', dir: 'ee')
              end
            end

            context 'Snowplow event tracking' do
              it_behaves_like 'Snowplow event tracking with RedisHLL context' do
                subject(:api_request) { get api(path, user) }

                let(:category) { 'EE::API::Groups' }
                let(:action) { 'group_audit_event_request' }
                let(:project) { nil }
                let(:namespace) { group }
                let(:context) { [::Gitlab::Tracking::ServicePingContext.new(data_source: :redis_hll, event: 'a_compliance_audit_events_api').to_context] }
              end
            end

            context 'invalid audit_event_id' do
              let(:path) { "/groups/#{group.id}/audit_events/an-invalid-id" }

              it_behaves_like '400 response' do
                let(:request) { get api(path, user) }
              end
            end

            context 'non existent audit event' do
              context 'non existent audit event of a group' do
                let(:path) { "/groups/#{group.id}/audit_events/666777" }

                it_behaves_like '404 response' do
                  let(:request) { get api(path, user) }
                end
              end

              context 'existing audit event of a different group' do
                let(:new_group) { create(:group) }
                let(:audit_event) { create(:audit_events_group_audit_event, created_at: Date.new(2000, 1, 10), group_id: new_group.id) }

                let(:path) { "/groups/#{group.id}/audit_events/#{audit_event.id}" }

                it_behaves_like '404 response' do
                  let(:request) { get api(path, user) }
                end
              end
            end
          end
        end
      end
    end
  end

  describe "DELETE /groups/:id" do
    subject { delete api("/groups/#{group.id}", user) }

    it 'does not mark the group for deletion when the group has a paid gitlab.com subscription', :saas do
      create(:gitlab_subscription, :ultimate, namespace: group)

      subject

      expect(response).to have_gitlab_http_status(:bad_request)
      expect(json_response['message']).to eq("This group can't be removed because it is linked to a subscription.")
      expect(group.marked_for_deletion_on).to be_nil
      expect(group.deleting_user).to be_nil
    end

    it 'marks for deletion a subgroup of a group with a paid gitlab.com subscription', :saas do
      create(:gitlab_subscription, :ultimate, namespace: group)
      subgroup = create(:group, parent: group)

      delete api("/groups/#{subgroup.id}", user)

      expect(response).to have_gitlab_http_status(:accepted)
      expect(subgroup.marked_for_deletion_on).to eq(Date.current)
      expect(subgroup.deleting_user).to eq(user)
    end

    it 'marks for deletion of a group with a trial plan', :saas do
      create(
        :gitlab_subscription,
        :ultimate_trial,
        :active_trial,
        namespace: group
      )

      subject

      expect(response).to have_gitlab_http_status(:accepted)
      expect(group.marked_for_deletion_on).to eq(Date.current)
      expect(group.deleting_user).to eq(user)
    end
  end

  describe 'GET /groups/:id/saml_users' do
    subject(:get_group_saml_users) do
      get api("/groups/#{group_id}/saml_users", current_user), params: params
    end

    let_it_be_with_reload(:group) { create(:group) }
    let_it_be_with_reload(:saml_provider) { create(:saml_provider, group: group) }

    let_it_be(:subgroup) { create(:group, parent: group) }

    let_it_be(:maintainer_of_the_group) { create(:user, maintainer_of: group) }
    let_it_be(:owner_of_the_group) { create(:user, owner_of: group) }

    let_it_be(:non_saml_user) { create(:user) }
    let_it_be(:saml_user_of_another_group) { create(:group_saml_identity).user }
    let_it_be(:non_saml_user_with_identity) { create(:omniauth_user, provider: 'google') }

    let_it_be(:saml_user_of_the_group) { create(:group_saml_identity, saml_provider: saml_provider).user }
    let_it_be(:saml_user_of_the_group2) { create(:group_saml_identity, saml_provider: saml_provider).user }

    let_it_be(:blocked_saml_user_of_the_group) do
      create(:group_saml_identity, saml_provider: saml_provider, user: create(:user, :blocked)).user
    end

    let(:current_user) { owner_of_the_group }
    let(:group_id) { group.id }
    let(:params) { {} }

    context 'when current_user is nil' do
      let(:current_user) { nil }

      it 'returns 401 Unauthorized' do
        get_group_saml_users

        expect(response).to have_gitlab_http_status(:unauthorized)
        expect(json_response['message']).to eq('401 Unauthorized')
      end
    end

    context 'when group is not found' do
      let(:group_id) { -42 }

      it 'returns 404 Group Not Found' do
        get_group_saml_users

        expect(response).to have_gitlab_http_status(:not_found)
        expect(json_response['message']).to eq('404 Group Not Found')
      end
    end

    context 'when group is not top-level group' do
      let(:group_id) { subgroup.id }

      it 'returns 400 Bad Request with message' do
        get_group_saml_users

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['message']).to eq('400 Bad request - Must be a top-level group')
      end
    end

    context 'when current_user is not owner of the group' do
      let(:current_user) { maintainer_of_the_group }

      it 'returns 403 Forbidden' do
        get_group_saml_users

        expect(response).to have_gitlab_http_status(:forbidden)
        expect(json_response['message']).to eq('403 Forbidden')
      end
    end

    it 'returns SAML users of the group in descending order by id' do
      get_group_saml_users

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response.pluck('id')).to eq(
        [
          saml_user_of_the_group,
          saml_user_of_the_group2,
          blocked_saml_user_of_the_group
        ].sort_by(&:id).reverse.pluck(:id)
      )
    end

    context 'when group does not have saml_provider' do
      before_all do
        saml_provider.destroy!
      end

      it 'does not return any users' do
        get_group_saml_users

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to eq([])
      end
    end

    context 'for pagination parameters' do
      let(:params) { { page: 1, per_page: 2 } }

      it 'returns SAML users according to page and per_page parameters' do
        get_group_saml_users

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.pluck('id')).to eq(
          [
            saml_user_of_the_group,
            saml_user_of_the_group2,
            blocked_saml_user_of_the_group
          ].sort_by(&:id).reverse.slice(0, 2).pluck(:id)
        )
      end
    end

    context 'for username parameter' do
      let(:params) { { username: saml_user_of_the_group.username } }

      it 'returns single SAML user with a specific username' do
        get_group_saml_users

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.count).to eq(1)
        expect(json_response.first['id']).to eq(saml_user_of_the_group.id)
      end
    end

    context 'for search parameter' do
      context 'for search by name' do
        let(:params) { { search: saml_user_of_the_group.name } }

        it 'returns SAML users of the group according to the search parameter' do
          get_group_saml_users

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.count).to eq(1)
          expect(json_response.first['id']).to eq(saml_user_of_the_group.id)
        end
      end

      context 'for search by username' do
        let(:params) { { search: blocked_saml_user_of_the_group.username } }

        it 'returns SAML users of the group according to the search parameter' do
          get_group_saml_users

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.count).to eq(1)
          expect(json_response.first['id']).to eq(blocked_saml_user_of_the_group.id)
        end
      end

      context 'for search by public email' do
        let_it_be(:saml_user_of_the_group_with_public_email) do
          create(:group_saml_identity, saml_provider: saml_provider, user: create(:user, :public_email)).user
        end

        let(:params) do
          { search: saml_user_of_the_group_with_public_email.public_email }
        end

        it 'returns SAML users of the group according to the search parameter' do
          expect(saml_user_of_the_group_with_public_email.public_email).to be_present

          get_group_saml_users

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.count).to eq(1)
          expect(json_response.first['id']).to eq(saml_user_of_the_group_with_public_email.id)
        end
      end

      context 'for search by private email' do
        let_it_be(:saml_user_of_the_group_without_public_email) do
          create(:group_saml_identity, saml_provider: saml_provider, user: create(:user)).user
        end

        let(:params) do
          { search: saml_user_of_the_group_without_public_email.email }
        end

        it 'returns SAML users of the group according to the search parameter' do
          expect(saml_user_of_the_group_without_public_email.public_email).not_to be_present

          get_group_saml_users

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.count).to eq(1)
          expect(json_response.first['id']).to eq(saml_user_of_the_group_without_public_email.id)
        end
      end
    end

    context 'for active parameter' do
      let(:params) { { active: true } }

      it 'returns only active SAML users' do
        get_group_saml_users

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.pluck('id')).to eq(
          [
            saml_user_of_the_group,
            saml_user_of_the_group2
          ].sort_by(&:id).reverse.pluck(:id)
        )
      end
    end

    context 'for blocked parameter' do
      let(:params) { { blocked: true } }

      it 'returns only blocked SAML users' do
        get_group_saml_users

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.pluck('id')).to eq(
          [
            blocked_saml_user_of_the_group
          ].sort_by(&:id).reverse.pluck(:id)
        )
      end
    end

    context 'for created_after parameter' do
      let(:params) { { created_after: 10.days.ago } }

      let_it_be(:saml_user_of_the_group_created_12_days_ago) do
        create(:group_saml_identity, saml_provider: saml_provider).user.tap do |user|
          user.update_column(:created_at, 12.days.ago)
        end
      end

      let_it_be(:saml_user_of_the_group_created_8_days_ago) do
        create(:group_saml_identity, saml_provider: saml_provider).user.tap do |user|
          user.update_column(:created_at, 8.days.ago)
        end
      end

      it 'returns only SAML users created after the specified time', :freeze_time do
        get_group_saml_users

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.pluck('id')).to eq(
          [
            saml_user_of_the_group,
            saml_user_of_the_group2,
            blocked_saml_user_of_the_group,
            saml_user_of_the_group_created_8_days_ago
          ].sort_by(&:id).reverse.pluck(:id)
        )
      end
    end

    context 'for created_before parameter' do
      let(:params) { { created_before: 10.days.ago } }

      let_it_be(:saml_user_of_the_group_created_12_days_ago) do
        create(:group_saml_identity, saml_provider: saml_provider).user.tap do |user|
          user.update_column(:created_at, 12.days.ago)
        end
      end

      let_it_be(:saml_user_of_the_group_created_8_days_ago) do
        create(:group_saml_identity, saml_provider: saml_provider).user.tap do |user|
          user.update_column(:created_at, 8.days.ago)
        end
      end

      it 'returns only SAML users created before the specified time', :freeze_time do
        get_group_saml_users

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.pluck('id')).to eq(
          [
            saml_user_of_the_group_created_12_days_ago
          ].sort_by(&:id).reverse.pluck(:id)
        )
      end
    end
  end

  describe 'GET /groups/:id/provisioned_users' do
    let_it_be(:group) { create(:group) }
    let_it_be(:regular_user) { create(:user) }
    let_it_be(:saml_provider) { create(:saml_provider, group: group) }
    let_it_be(:scim_identity) { create(:group_scim_identity, group: group) }
    let_it_be(:developer) { create(:user, developer_of: group) }
    let_it_be(:maintainer) { create(:user, maintainer_of: group) }

    let_it_be(:provisioned_user) { create(:user, provisioned_by_group_id: group.id, created_at: 2.years.ago) }
    let_it_be(:blocked_provisioned_user) { create(:user, :blocked, provisioned_by_group_id: group.id) }
    let_it_be(:non_provisioned_user) { create(:user) { |u| group.add_maintainer(u) } }

    let(:params) { {} }

    subject(:get_provisioned_users) { get api("/groups/#{group.to_param}/provisioned_users", current_user), params: params }

    context 'when current_user is not a group maintainer' do
      let_it_be(:current_user) { developer }

      it 'returns 403' do
        get_provisioned_users

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when current_user is a group maintainer' do
      let_it_be(:current_user) { maintainer }

      it 'returns a list of users provisioned by the group' do
        get_provisioned_users

        expect(json_response.pluck('id')).to eq([blocked_provisioned_user.id, provisioned_user.id])
      end

      context 'optional params' do
        context 'search param' do
          let(:params) { { search: provisioned_user.email } }

          it 'filters by search' do
            get_provisioned_users

            expect(json_response.pluck('id')).to eq([provisioned_user.id])
          end
        end

        context 'username param' do
          let(:params) { { username: provisioned_user.username } }

          it 'filters by username' do
            get_provisioned_users

            expect(json_response.pluck('id')).to eq([provisioned_user.id])
          end
        end

        context 'blocked param' do
          let(:params) { { blocked: true } }

          it 'filters by blocked' do
            get_provisioned_users

            expect(json_response.pluck('id')).to eq([blocked_provisioned_user.id])
          end
        end

        context 'active param' do
          let(:params) { { active: true } }

          it 'filters by active status' do
            get_provisioned_users

            expect(json_response.pluck('id')).to eq([provisioned_user.id])
          end
        end

        context 'created_after' do
          let(:params) { { created_after: 1.year.ago } }

          it 'filters by created_at' do
            get_provisioned_users

            expect(json_response.pluck('id')).to eq([blocked_provisioned_user.id])
          end
        end

        context 'created_before' do
          let(:params) { { created_before: 1.year.ago } }

          it 'filters by created_at' do
            get_provisioned_users

            expect(json_response.pluck('id')).to eq([provisioned_user.id])
          end
        end
      end
    end
  end

  describe 'GET /groups/:id/users' do
    let_it_be(:group) { create(:group, :private) }
    let_it_be(:regular_user) { create(:user) }
    let_it_be_with_refind(:saml_provider) { create(:saml_provider, group: group, enforced_sso: true) }
    let_it_be(:group_member_user) { create(:user) { |u| group.add_owner(u) } }

    let_it_be(:saml_user) { create(:user, :public_email) }
    let_it_be(:non_saml_user) { create(:user) { |u| group.add_maintainer(u) } }
    let_it_be(:service_account) { create(:service_account, provisioned_by_group: group) }

    subject(:get_users) { get api("/groups/#{group.to_param}/users", current_user), params: params }

    before do
      stub_licensed_features(group_saml: true)
      create(:group_saml_identity, user: group_member_user, saml_provider: saml_provider)
      create(:group_saml_identity, user: saml_user, saml_provider: saml_provider)
    end

    context 'when current_user is not a group member' do
      let(:params) { { include_saml_users: true, include_service_accounts: true } }

      let_it_be(:current_user) { regular_user }

      it 'returns 404' do
        get_users

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    shared_examples 'authorized current_user responses' do
      context 'when no include params are present' do
        let(:params) { {} }

        it 'returns 400' do
          get_users

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end

      context 'when no include params are true' do
        let(:params) { { include_saml_users: false } }

        it 'returns 400' do
          get_users

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end

      context 'when all include params are present' do
        let(:params) { { include_saml_users: true, include_service_accounts: true } }

        it 'returns a list of matching users' do
          get_users

          expect(json_response.pluck('id')).to match_array([group_member_user.id, saml_user.id, service_account.id])
        end

        context 'when no SAML provider exists' do
          it 'returns 403' do
            saml_provider.destroy!

            get_users

            expect(response).to have_gitlab_http_status(:forbidden)
          end
        end
      end

      context 'when only include_saml_users is true' do
        let(:params) { { include_saml_users: true } }

        it 'returns only SAML users' do
          get_users

          expect(json_response.pluck('id')).to match_array([group_member_user.id, saml_user.id])
        end
      end

      context 'when only include_service_accounts is true' do
        let(:params) { { include_service_accounts: true } }

        it 'returns only service accounts' do
          get_users

          expect(json_response.pluck('id')).to match_array([service_account.id])
        end
      end

      context 'optional params' do
        context 'search param' do
          let(:params) { { include_saml_users: true, include_service_accounts: true, search: saml_user.email } }

          it 'filters by search' do
            get_users

            expect(json_response.pluck('id')).to match_array([saml_user.id])
          end
        end
      end
    end

    context 'when current_user is an admin', :enable_admin_mode do
      let_it_be(:current_user) { create(:admin) }

      it_behaves_like 'authorized current_user responses'
    end

    context 'when current_user is a group member' do
      let_it_be(:current_user) { group_member_user }

      it_behaves_like 'authorized current_user responses'
    end
  end

  shared_examples_for 'when unauthenticated' do
    it_behaves_like '401 response' do
      let(:message) { '401 Unauthorized' }
    end
  end

  shared_examples_for 'when authenticated as maintainer' do
    it_behaves_like '403 response' do
      let(:message) { '403 Forbidden' }
    end
  end

  shared_examples_for 'when premium feature not available' do
    before do
      stub_licensed_features(ssh_certificates: false)
    end

    it_behaves_like '404 response' do
      let(:message) { '404 Not Found' }
    end
  end

  shared_examples_for "when group doesn't exist" do
    let(:route) { '/groups/9999/ssh_certificates' }

    it_behaves_like '404 response' do
      let(:message) { '404 Group Not Found' }
    end
  end

  shared_examples_for 'when group is not a top level group' do
    let_it_be(:subgroup) { create(:group, parent: group) }

    it_behaves_like '403 response' do
      let(:message) { '403 Forbidden Group' }
    end
  end

  describe 'GET /groups/:id/ssh_certificates' do
    let(:route) { "/groups/#{group.id}/ssh_certificates" }

    before do
      stub_licensed_features(ssh_certificates: true)
    end

    context 'when unauthenticated' do
      it_behaves_like '403 response' do
        let(:request) { get api(route) }
      end
    end

    it_behaves_like 'when authenticated as maintainer' do
      before do
        group.add_maintainer(user)
      end

      let(:request) { get api(route, user) }
    end

    context 'when authenticated as owner' do
      let(:request) { get api(route, user) }

      it_behaves_like "when group doesn't exist" do
        let(:route) { '/groups/9999/ssh_certificates' }
      end

      it_behaves_like 'when premium feature not available'

      it_behaves_like 'when group is not a top level group' do
        let(:route) { "/groups/#{subgroup.id}/ssh_certificates" }
      end

      context 'when no ssh certificates are found' do
        before do
          private_group.add_owner(user)
        end

        let(:route) { "/groups/#{private_group.id}/ssh_certificates" }

        it 'returns an empty array' do
          request

          expect_empty_array_response
        end
      end

      it 'returns an array of ssh_certificates' do
        request
        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to be_an Array
        expect(response).to include_pagination_headers
        expect(json_response.length).to eq 2
        expect(json_response.first['title']).to include('My title')
        expect(json_response.first['key']).to include('ssh-rsa ')
      end
    end
  end

  describe 'POST /groups/:id/ssh_certificates' do
    let(:route) { "/groups/#{group.id}/ssh_certificates" }
    let(:title) { 'ssh cert from post request' }
    let(:key) { 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAAgQCxT+aWnicS3k2ckFuoaGH3lapt28Wbif72onlVdHIhtUXZCixzs9r+jw2kme4GkUP/u6YUYJ0eEnEQR76uRje1xtoEUeM/JoC43iFX+3jbOd32gTSWe0NNWtdwLBbt8NqeDGv3WbYAKZfZpEfV7ipb70ju9ML1i94SC45NzbzcRQ== example@gitlab.com' }
    let(:params) do
      {
        title: title,
        key: key
      }
    end

    before do
      stub_licensed_features(ssh_certificates: true)
    end

    it_behaves_like 'when unauthenticated' do
      let(:request) { post api(route) }
    end

    it_behaves_like 'when authenticated as maintainer' do
      before do
        group.add_maintainer(user)
      end

      let(:request) { post api(route, user), params: params }
    end

    context 'when authenticated as owner' do
      let(:request) { post api(route, user), params: params }

      context 'when title param is empty' do
        let(:title) { '' }

        it_behaves_like '422 response' do
          let(:message) { "Validation failed: Title can't be blank" }
        end
      end

      context 'when key param is empty' do
        let(:key) { '' }

        it_behaves_like '422 response' do
          let(:message) { 'Validation failed: Invalid key' }
        end
      end

      context 'when key param is incorrectly formatted' do
        let(:key) { 'xxx' }

        it_behaves_like '422 response' do
          let(:message) { "Validation failed: Invalid key" }
        end
      end

      it_behaves_like "when group doesn't exist" do
        let(:route) { '/groups/9999/ssh_certificates' }
      end

      it_behaves_like 'when premium feature not available'

      it_behaves_like 'when group is not a top level group' do
        let(:route) { "/groups/#{subgroup.id}/ssh_certificates" }
      end

      it 'adds an ssh_certificate to the group' do
        request
        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['title']).to eq('ssh cert from post request')
        expect(json_response['key']).to include('ssh-rsa ')
      end
    end
  end

  describe "POST /groups/:id/share" do
    let_it_be(:invited_group) { create(:group) }

    subject(:share) { post api("/groups/#{group.id}/share", user), params: params }

    context 'when block seat overages is enabled', :saas do
      before_all do
        create(:gitlab_subscription, :premium, namespace: group)
      end

      before do
        stub_saas_features(gitlab_com_subscriptions: true)
        group.namespace_settings.update!(seat_control: :block_overages)
      end

      context 'when the invited group is outside the hierarchy' do
        let(:params) { { group_id: invited_group.id, group_access: Gitlab::Access::DEVELOPER } }

        it 'does not allow sharing' do
          share

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response).to eq({ 'message' => 'Not Found' })
          expect(group.reload.shared_with_groups).to be_empty
        end
      end

      context 'when the invited group is inside the hierarchy' do
        let_it_be(:group) { create(:group, parent: group) }
        let_it_be(:other_subgroup) { create(:group, parent: group) }

        let(:params) { { group_id: other_subgroup.id, group_access: Gitlab::Access::DEVELOPER } }

        it 'allows sharing' do
          share

          expect(response).to have_gitlab_http_status(:created)
          expect(group.reload.shared_with_groups).to eq([other_subgroup])
        end
      end
    end

    context 'when assigning a member role' do
      let_it_be(:member_role) { create(:member_role, :instance) }

      let(:params) { { group_id: invited_group.id, group_access: Gitlab::Access::DEVELOPER, member_role_id: member_role.id } }

      before do
        allow_next_instance_of(::Groups::GroupLinks::CreateService) do |service|
          allow(service).to receive(:custom_role_for_group_link_enabled?)
            .with(group)
            .and_return(custom_role_for_group_link_enabled)
        end
      end

      context 'when custom_roles feature is enabled' do
        before do
          stub_licensed_features(custom_roles: true)
        end

        context 'when `custom_role_for_group_link_enabled` is true' do
          let(:custom_role_for_group_link_enabled) { true }

          it 'assigns member role to group link' do
            share

            expect(response).to have_gitlab_http_status(:created)
            expect(json_response['shared_with_groups'][0]['member_role_id']).to eq(member_role.id)
          end
        end

        context 'when `custom_role_for_group_link_enabled` is false' do
          let(:custom_role_for_group_link_enabled) { false }

          it 'does not assign member role to group link' do
            share

            expect(response).to have_gitlab_http_status(:created)
            expect(json_response['shared_with_groups'][0]['member_role_id']).to be_nil
          end
        end
      end

      context 'when custom_roles feature is disabled' do
        let(:custom_role_for_group_link_enabled) { false }

        before do
          stub_licensed_features(custom_roles: false)
        end

        it 'does not assign member role to group link' do
          share

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['shared_with_groups'][0]['member_role_id']).to be_nil
        end
      end
    end
  end

  describe 'DELETE /groups/:id/ssh_certificates/:ssh_certificates_id' do
    let(:route) { "/groups/#{group.id}/ssh_certificates/#{ssh_certificate_1.id}" }

    before do
      stub_licensed_features(ssh_certificates: true)
    end

    it_behaves_like 'when unauthenticated' do
      let(:request) { delete api(route) }
    end

    it_behaves_like 'when authenticated as maintainer' do
      before do
        group.add_maintainer(user)
      end

      let(:request) { delete api(route, user) }
    end

    context 'when authenticated as owner' do
      let(:request) { delete api(route, user) }

      it_behaves_like "when group doesn't exist" do
        let(:route) { "/groups/9999/ssh_certificates/#{ssh_certificate_1.id}" }
      end

      it_behaves_like 'when premium feature not available'

      it_behaves_like 'when group is not a top level group' do
        let(:route) { "/groups/#{subgroup.id}/ssh_certificates/#{ssh_certificate_1.id}" }
      end

      context "when ssh cert doesn't exist" do
        let(:route) { "/groups/#{group.id}/ssh_certificates/9999" }

        it_behaves_like '404 response' do
          let(:message) { 'SSH Certificate not found' }
        end
      end

      context 'when ssh cert cannot be deleted' do
        before do
          # new object loaded in ee/lib/ee/api/groups.rb via find.
          # cant stub the find on an active record association (group.ssh_certificates.find)
          # disabling the rubocop instead.
          allow_any_instance_of(Groups::SshCertificate).to receive(:destroy!).and_raise(ActiveRecord::RecordNotDestroyed) # rubocop:disable RSpec/AnyInstanceOf
        end

        it '405 response' do
          request
          expect(response).to have_gitlab_http_status(:method_not_allowed)

          expect(response.body).to include('SSH Certificate could not be deleted')
        end
      end

      it 'deletes the ssh_certificate' do
        expect(group.ssh_certificates.size).to eq(2)
        request
        expect(response).to have_gitlab_http_status(:no_content)
        expect(group.ssh_certificates.reload.size).to eq(1)
      end
    end
  end

  def ldap_sync(group_id, user, sidekiq_testing_method, admin_mode = false)
    Sidekiq::Testing.send(sidekiq_testing_method) do
      post api("/groups/#{group_id}/ldap_sync", user, admin_mode: admin_mode)
    end
  end
end
