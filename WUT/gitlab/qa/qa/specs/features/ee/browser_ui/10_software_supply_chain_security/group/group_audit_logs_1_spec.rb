# frozen_string_literal: true

module QA
  RSpec.describe 'Software Supply Chain Security', :skip_live_env, product_group: :compliance, feature_flag: {
    name: :show_role_details_in_drawer
  } do
    shared_examples 'audit event' do |expected_events|
      it 'logs audit events for UI operations' do
        wait_for_audit_events(expected_events, group)

        Page::Group::Menu.perform(&:go_to_audit_events)
        expected_events.each do |expected_event|
          # Sometimes the audit logs are not displayed in the UI
          # right away so a refresh may be needed.
          # https://gitlab.com/gitlab-org/gitlab/issues/119203
          # TODO: https://gitlab.com/gitlab-org/gitlab/issues/195424
          Support::Retrier.retry_on_exception(reload_page: page) do
            expect(page).to have_text(expected_event)
          end
        end
      end
    end

    describe 'Group' do
      let(:group) { create(:group, path: "test-group-#{SecureRandom.hex(8)}") }
      let(:project) { create(:project, name: 'project-shared-with-group') }
      let(:user) { Runtime::User::Store.additional_test_user }

      # rubocop:disable RSpec/InstanceVariable -- TODO remove instance variable usage
      before do
        @event_count = get_audit_event_count(group)
      end

      context 'for add group',
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347910' do
        before do
          @event_count = 0
          sign_in
          Resource::Group.fabricate_via_browser_ui! do |group|
            group.path = "group-to-test-audit-event-log-#{SecureRandom.hex(8)}"
          end
        end

        it_behaves_like 'audit event', ['Added group']
      end

      context 'for change repository size limit', :requires_admin,
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347908' do
        before do
          sign_in(as_admin: true)
          group.visit!
          Page::Group::Menu.perform(&:go_to_general_settings)
          Page::Group::Settings::General.perform do |settings|
            settings.set_repository_size_limit(100)
            settings.click_save_name_visibility_settings_button
          end
        end

        it_behaves_like 'audit event', ['Changed repository size limit']
      end

      context 'for update group name',
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347909' do
        before do
          sign_in
          group.visit!
          updated_group_name = "#{group.path}-updated"
          Page::Group::Menu.perform(&:go_to_general_settings)
          Page::Group::Settings::General.perform do |settings|
            settings.set_group_name(updated_group_name)
            settings.click_save_name_visibility_settings_button
          end
        end

        it_behaves_like 'audit event', ['Changed name']
      end

      context 'for add user, change access level, remove user',
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347911' do
        before do
          sign_in
          group.visit!
          Page::Group::Menu.perform(&:go_to_members)
          Page::Group::Members.perform do |members_page|
            members_page.add_member(user.username, 'Guest')
            members_page.update_access_level(user.username, "Developer")
            members_page.remove_member(user.username)
          end
        end

        it_behaves_like 'audit event',
          ['Added user access as Default role: Guest', 'Changed access level', 'Removed user access']
      end

      context 'for add and remove project access',
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347912' do
        before do
          sign_in
          project.visit!

          Page::Project::Menu.perform(&:go_to_members)
          Page::Project::Members.perform do |members|
            members.invite_group(group.path)
          end

          Page::Project::Menu.perform(&:go_to_members)
          Page::Project::Members.perform do |members|
            members.remove_group(group.path)
          end

          group.visit!
        end

        it_behaves_like 'audit event', ['Added project access', 'Removed project access']
      end
    end

    def sign_in(as_admin: false)
      return if Page::Main::Menu.perform(&:signed_in?)

      Runtime::Feature.disable(:show_role_details_in_drawer)
      Runtime::Browser.visit(:gitlab, Page::Main::Login)
      Page::Main::Login.perform do |login|
        as_admin ? login.sign_in_using_admin_credentials : login.sign_in_using_credentials
      end
    end

    def get_audit_event_count(group)
      group.audit_events.length
    end

    def wait_for_audit_events(expected_events, group)
      new_event_count = @event_count + expected_events.length

      Support::Retrier.retry_until(max_duration: QA::Support::Repeater::DEFAULT_MAX_WAIT_TIME, sleep_interval: 1) do
        get_audit_event_count(group) >= new_event_count
      end
    end
    # rubocop:enable RSpec/InstanceVariable
  end
end
