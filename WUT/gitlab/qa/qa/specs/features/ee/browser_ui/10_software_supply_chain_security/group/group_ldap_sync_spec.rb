# frozen_string_literal: true

module QA
  RSpec.describe 'Software Supply Chain Security', :orchestrated, :ldap_tls, :ldap_no_tls, :requires_admin do
    describe 'LDAP Group sync', product_group: :authentication do
      include Support::API

      let(:root_group) { create(:sandbox, path: "group_sync_root_group-#{SecureRandom.hex(4)}") }
      let(:group) { create(:group, sandbox: root_group, path: "#{group_name}-#{SecureRandom.hex(4)}") }
      let(:project) { create(:project, name: "project-to-test-PrAT-#{SecureRandom.hex(8)}", group: group) }

      shared_examples 'Group sync' do |testcases|
        it 'has LDAP users synced', testcase: testcases[0] do
          Page::Group::Menu.perform(&:go_to_members)

          EE::Page::Group::Members.perform do |members|
            members.click_sync_now_if_needed

            users_synchronised = members.retry_until(reload: true) do
              sync_users.map { |user| members.has_content?(user) }.all?
            end

            expect(users_synchronised).to be_truthy
          end

          it 'can create group access tokens', testcase: testcases[1] do
            expect do
              create(:group_access_token, group: group, api_client: Runtime::API::Client.as_admin)
            end.not_to raise_error
          end

          it 'can create project access tokens', testcase: testcases[2] do
            project

            expect do
              create(:project_access_token, project: project)
            end.not_to raise_error
          end
        end

        context 'with group cn method' do
          let(:ldap_users) do
            [
              {
                name: 'ENG User 1',
                username: 'enguser1',
                email: 'enguser1@example.org',
                provider: 'ldapmain',
                extern_uid: 'uid=enguser1,ou=people,ou=global groups,dc=example,dc=org'
              },
              {
                name: 'ENG User 2',
                username: 'enguser2',
                email: 'enguser2@example.org',
                provider: 'ldapmain',
                extern_uid: 'uid=enguser2,ou=people,ou=global groups,dc=example,dc=org'
              },
              {
                name: 'ENG User 3',
                username: 'enguser3',
                email: 'enguser3@example.org',
                provider: 'ldapmain',
                extern_uid: 'uid=enguser3,ou=people,ou=global groups,dc=example,dc=org'
              }
            ]
          end

          let(:owner_user) { 'enguser1' }
          let(:sync_users) { ['ENG User 2', 'ENG User 3'] }

          let(:group_name) { 'Synched-engineering-group' }

          before do
            created_users = create_users_via_api(ldap_users)

            group.add_member(created_users[owner_user], Resource::Members::AccessLevel::OWNER)

            signin_as_user(owner_user)

            group.visit!

            Page::Group::Menu.perform(&:go_to_ldap_sync_settings)

            EE::Page::Group::Settings::LDAPSync.perform do |settings|
              settings.set_ldap_group_sync_method
              settings.set_group_cn('Engineering')
              settings.set_ldap_access('Guest')
              settings.click_add_sync_button
            end
          end

          it_behaves_like 'Group sync', %w[https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347894
            https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/385267
            https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/385266]
        end

        context 'with user filter method' do
          let(:ldap_users) do
            [
              {
                name: 'HR User 1',
                username: 'hruser1',
                email: 'hruser1@example.org',
                provider: 'ldapmain',
                extern_uid: 'uid=hruser1,ou=people,ou=global groups,dc=example,dc=org'
              },
              {
                name: 'HR User 2',
                username: 'hruser2',
                email: 'hruser2@example.org',
                provider: 'ldapmain',
                extern_uid: 'uid=hruser2,ou=people,ou=global groups,dc=example,dc=org'
              },
              {
                name: 'HR User 3',
                username: 'hruser3',
                email: 'hruser3@example.org',
                provider: 'ldapmain',
                extern_uid: 'uid=hruser3,ou=people,ou=global groups,dc=example,dc=org'
              }
            ]
          end

          let(:owner_user) { 'hruser1' }
          let(:sync_users) { ['HR User 2', 'HR User 3'] }

          let(:group_name) { 'Synched-human-resources-group' }

          before do
            created_users = create_users_via_api(ldap_users)

            group.add_member(created_users[owner_user], Resource::Members::AccessLevel::OWNER)

            signin_as_user(owner_user)

            group.visit!

            Page::Group::Menu.perform(&:go_to_ldap_sync_settings)

            EE::Page::Group::Settings::LDAPSync.perform do |settings|
              settings.set_ldap_user_filter_sync_method
              settings.set_user_filter('(&(objectClass=person)(cn=HR*))')
              settings.set_ldap_access('Guest')
              settings.click_add_sync_button
            end

            Page::Group::Menu.perform(&:go_to_members)
          end

          it_behaves_like 'Group sync', %w[https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347893
            https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/385269
            https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/385270]
        end

        def create_users_via_api(users)
          created_users = {}

          users.each do |user|
            created_users[user[:username]] = create(:user,
              username: user[:username],
              name: user[:name],
              email: user[:email],
              extern_uid: user[:extern_uid],
              provider: user[:provider],
              api_client: Runtime::API::Client.as_admin)
          end
          created_users
        end

        def signin_as_user(user_name)
          user = Struct.new(:username, :password).new(user_name, 'password')

          Page::Main::Menu.perform(&:sign_out_if_signed_in)
          Runtime::Browser.visit(:gitlab, Page::Main::Login)

          Page::Main::Login.perform do |login_page|
            login_page.sign_in_using_ldap_credentials(user: user)
          end
        end

        def verify_users_synced(expected_users); end
      end
    end
  end
end
