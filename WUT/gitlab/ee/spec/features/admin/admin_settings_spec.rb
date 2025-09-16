# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Admin updates EE-only settings', :with_current_organization, feature_category: :shared do
  include Spec::Support::Helpers::ModalHelpers
  include ListboxHelpers

  let_it_be(:admin) { create(:admin) }

  before do
    stub_env('IN_MEMORY_APPLICATION_SETTINGS', 'false')
    sign_in(admin)
    enable_admin_mode!(admin)
    allow(License).to receive(:feature_available?).and_return(true)
    allow(Gitlab::Elastic::Helper.default).to receive(:index_exists?).and_return(true)
  end

  describe 'Geo settings', feature_category: :geo_replication do
    context 'when the license has Geo feature' do
      before do
        visit admin_geo_settings_path
      end

      it 'hides JS alert' do
        expect(page).not_to have_content("Geo is only available for users who have at least a Premium subscription.")
      end

      it 'renders JS form' do
        expect(page).to have_css("#js-geo-settings-form")
      end
    end

    context 'when the license does not have Geo feature' do
      before do
        allow(License).to receive(:feature_available?).and_return(false)
        visit admin_geo_settings_path
      end

      it 'shows JS alert' do
        expect(page).to have_content("Geo is only available for users who have at least a Premium subscription.")
      end
    end
  end

  describe 'external authentication', feature_category: :system_access do
    it 'enables external authentication' do
      visit general_admin_application_settings_path
      within_testid('external-auth-settings') do
        check 'Enable classification control using an external service'
        fill_in 'Default classification label', with: 'default'
        click_button 'Save changes'
      end

      expect(page).to have_content 'Application settings saved successfully'
    end
  end

  describe 'Search settings', :elastic_delete_by_query, feature_category: :global_search do
    let(:elastic_search_license) { true }

    let(:task) do
      create(:elastic_reindexing_task).tap do |task|
        allow(task).to receive_messages(in_progress?: false, error_message: nil, state: "indexing_paused")
      end
    end

    let(:subtask) do
      create(:elastic_reindexing_subtask, documents_count: 0, documents_count_target: 0, reindexing_task: task)
    end

    before do
      stub_licensed_features(elastic_search: elastic_search_license)
      allow(::Search::Elastic::ReindexingTask).to receive(:last).and_return(task)
    end

    it 'changes elasticsearch settings' do
      visit search_admin_application_settings_path

      within_testid('elasticsearch-settings') do
        check 'Elasticsearch indexing'
        check 'Search with Elasticsearch enabled'

        fill_in 'application_setting_elasticsearch_shards[gitlab-test]', with: '120'
        fill_in 'application_setting_elasticsearch_replicas[gitlab-test]', with: '2'
        fill_in 'application_setting_elasticsearch_shards[gitlab-test-issues]', with: '10'
        fill_in 'application_setting_elasticsearch_replicas[gitlab-test-issues]', with: '3'
        fill_in 'application_setting_elasticsearch_shards[gitlab-test-notes]', with: '20'
        fill_in 'application_setting_elasticsearch_replicas[gitlab-test-notes]', with: '4'
        fill_in 'application_setting_elasticsearch_shards[gitlab-test-merge_requests]', with: '15'
        fill_in 'application_setting_elasticsearch_replicas[gitlab-test-merge_requests]', with: '5'
        fill_in 'application_setting_elasticsearch_shards[gitlab-test-commits]', with: '25'
        fill_in 'application_setting_elasticsearch_replicas[gitlab-test-commits]', with: '6'

        fill_in 'Maximum file size indexed (KiB)', with: '5000'
        fill_in 'Maximum field length', with: '100000'
        fill_in 'Maximum bulk request size (MiB)', with: '17'
        fill_in 'Bulk request concurrency', with: '23'
        fill_in 'Client request timeout', with: '30'

        click_button 'Save changes'
      end

      aggregate_failures do
        expect(current_settings.elasticsearch_indexing).to be_truthy
        expect(current_settings.elasticsearch_search).to be_truthy

        expect(current_settings.elasticsearch_shards).to eq(120)
        expect(current_settings.elasticsearch_replicas).to eq(2)
        expect(Elastic::IndexSetting['gitlab-test'].number_of_shards).to eq(120)
        expect(Elastic::IndexSetting['gitlab-test'].number_of_replicas).to eq(2)
        expect(Elastic::IndexSetting['gitlab-test-issues'].number_of_shards).to eq(10)
        expect(Elastic::IndexSetting['gitlab-test-issues'].number_of_replicas).to eq(3)
        expect(Elastic::IndexSetting['gitlab-test-notes'].number_of_shards).to eq(20)
        expect(Elastic::IndexSetting['gitlab-test-notes'].number_of_replicas).to eq(4)
        expect(Elastic::IndexSetting['gitlab-test-merge_requests'].number_of_shards).to eq(15)
        expect(Elastic::IndexSetting['gitlab-test-merge_requests'].number_of_replicas).to eq(5)
        expect(Elastic::IndexSetting['gitlab-test-commits'].number_of_shards).to eq(25)
        expect(Elastic::IndexSetting['gitlab-test-commits'].number_of_replicas).to eq(6)

        expect(current_settings.elasticsearch_indexed_file_size_limit_kb).to eq(5000)
        expect(current_settings.elasticsearch_indexed_field_length_limit).to eq(100000)
        expect(current_settings.elasticsearch_max_bulk_size_mb).to eq(17)
        expect(current_settings.elasticsearch_max_bulk_concurrency).to eq(23)
        expect(current_settings.elasticsearch_client_request_timeout).to eq(30)
        expect(page).to have_content 'Application settings saved successfully'
      end
    end

    it 'allows limiting projects and namespaces to index', :aggregate_failures, :js do
      project = create(:project)
      namespace = create(:namespace)

      visit search_admin_application_settings_path

      within_testid('elasticsearch-settings') do
        expect(page).not_to have_content('Namespaces to index')
        expect(page).not_to have_content('Projects to index')

        check 'Limit the amount of namespace and project data to index'

        expect(page).to have_content('Namespaces to index')
        expect(page).to have_content('Projects to index')

        click_button 'Select namespaces to index'
        send_keys namespace.path
        wait_for_requests
        select_listbox_item namespace.full_path

        click_button 'Select projects to index'
        send_keys project.path
        wait_for_requests
        select_listbox_item project.name_with_namespace

        click_button 'Save changes'
      end

      expect(current_settings.elasticsearch_limit_indexing).to be_truthy
      expect(ElasticsearchIndexedNamespace.exists?(namespace_id: namespace.id)).to be_truthy
      expect(ElasticsearchIndexedProject.exists?(project_id: project.id)).to be_truthy
    end

    it 'allows removing all namespaces and projects', :aggregate_failures, :js do
      stub_ee_application_setting(elasticsearch_limit_indexing: true)

      namespace = create(:elasticsearch_indexed_namespace).namespace
      project = create(:elasticsearch_indexed_project).project

      expect(ElasticsearchIndexedNamespace.count).to be > 0
      expect(ElasticsearchIndexedProject.count).to be > 0

      visit search_admin_application_settings_path

      within_testid('elasticsearch-settings') do
        expect(page).to have_content('Namespaces to index')
        expect(page).to have_content('Projects to index')
        expect(page).to have_content(namespace.full_path)
        expect(page).to have_content(project.full_path)

        find('.js-limit-namespaces button[data-testid="remove-index-entity"]').click
        find('.js-limit-projects button[data-testid="remove-index-entity"]').click

        expect(page).not_to have_content(namespace.full_path)
        expect(page).not_to have_content(project.full_path)

        click_button 'Save changes'
      end

      expect(ElasticsearchIndexedNamespace.count).to eq(0)
      expect(ElasticsearchIndexedProject.count).to eq(0)
      expect(page).to have_content 'Application settings saved successfully'
    end

    it 'zero-downtime reindexing shows popup', :js do
      visit search_admin_application_settings_path

      within_testid('elasticsearch-reindexing-settings') do
        expect(page).to have_content 'Trigger cluster reindexing'
        click_button 'Trigger cluster reindexing'
      end

      accept_gl_confirm('Are you sure you want to reindex?')
    end

    context 'when not licensed' do
      let(:elastic_search_license) { false }

      it 'cannot access the page' do
        visit search_admin_application_settings_path

        expect(page).not_to have_content("Advanced Search with Elasticsearch")
      end
    end
  end

  describe 'Templates page', feature_category: :importers do
    before do
      visit templates_admin_application_settings_path
    end

    it 'render "Templates" section' do
      within_testid('templates-settings') do
        expect(page).to have_content 'Templates'
      end
    end

    it 'render "Custom project templates" section' do
      within_testid('custom-project-template-container') do
        expect(page).to have_content 'Custom project templates'
      end
    end
  end

  describe 'LDAP settings', feature_category: :system_access do
    before do
      allow(Gitlab::Auth::Ldap::Config).to receive(:enabled?).and_return(ldap_setting)

      visit general_admin_application_settings_path
    end

    context 'with LDAP enabled' do
      let(:ldap_setting) { true }

      it 'changes to allow group owners to manage ldap' do
        within_testid('admin-visibility-access-settings') do
          find('#application_setting_allow_group_owners_to_manage_ldap').set(false)
          click_button 'Save'
        end

        expect(page).to have_content('Application settings saved successfully')
        expect(find('#application_setting_allow_group_owners_to_manage_ldap')).not_to be_checked
      end
    end

    context 'with LDAP disabled' do
      let(:ldap_setting) { false }

      it 'does not show option to allow group owners to manage ldap' do
        expect(page).not_to have_css('#application_setting_allow_group_owners_to_manage_ldap')
      end
    end
  end

  describe 'Disable personal access tokens', feature_category: :system_access do
    it 'does not show the setting when the feature is not licensed' do
      stub_licensed_features(disable_personal_access_tokens: false)

      expect(page).not_to have_css('#application_setting_disable_personal_access_tokens')
    end

    it 'enables personal access tokens' do
      current_settings.update_attribute(:disable_personal_access_tokens, true)

      visit general_admin_application_settings_path

      within_testid('account-and-limit-settings-content') do
        uncheck s_('AccessTokens|Disable access tokens')
        click_button _('Save changes')
      end

      expect(page).to have_content _('Application settings saved successfully')
      expect(find('#application_setting_disable_personal_access_tokens')).not_to be_checked
      expect(current_settings.disable_personal_access_tokens).to be(false)
    end
  end

  describe 'Disable group invite members', feature_category: :system_access do
    it 'does not show the setting when the feature is not licensed' do
      stub_licensed_features(disable_invite_members: false)

      expect(page).not_to have_css('#application_setting_disable_invite_members')
    end

    it 'enables personal access tokens' do
      current_settings.update_attribute(:disable_invite_members, true)

      visit general_admin_application_settings_path

      within_testid('admin-visibility-access-settings') do
        uncheck _('Disable inviting new members to group or project by group/project owners or project maintainers')
        click_button _('Save changes')
      end

      expect(page).to have_content _('Application settings saved successfully')
      expect(current_settings.disable_personal_access_tokens).to be(false)
    end
  end

  describe 'package registry settings', feature_category: :package_registry do
    before do
      visit ci_cd_admin_application_settings_path
    end

    it 'allows you to change the maven_forwarding setting' do
      within_testid('forward-package-requests-form') do
        check 'Forward Maven package requests'
        click_button 'Save'
      end

      expect(current_settings.maven_package_requests_forwarding).to be true
    end

    it 'allows you to change the maven_lock setting' do
      within_testid('forward-package-requests-form') do
        check 'Enforce Maven setting for all subgroups'
        click_button 'Save'
      end

      expect(current_settings.lock_maven_package_requests_forwarding).to be true
    end

    it 'allows you to change the npm_forwarding setting' do
      within_testid('forward-package-requests-form') do
        check 'Forward npm package requests'
        click_button 'Save'
      end

      expect(current_settings.npm_package_requests_forwarding).to be true
    end

    it 'allows you to change the npm_lock setting' do
      within_testid('forward-package-requests-form') do
        check 'Enforce npm setting for all subgroups'
        click_button 'Save'
      end

      expect(current_settings.lock_npm_package_requests_forwarding).to be true
    end

    it 'allows you to change the pypi_forwarding setting' do
      within_testid('forward-package-requests-form') do
        check 'Forward PyPI package requests'
        click_button 'Save'
      end

      expect(current_settings.pypi_package_requests_forwarding).to be true
    end

    it 'allows you to change the pypi_lock setting' do
      within_testid('forward-package-requests-form') do
        check 'Enforce PyPI setting for all subgroups'
        click_button 'Save'
      end

      expect(current_settings.lock_pypi_package_requests_forwarding).to be true
    end
  end

  context 'with virtual registries settings', feature_category: :virtual_registry do
    let(:dependency_proxy_feature_enabled) { true }

    before do
      stub_config(dependency_proxy: { enabled: dependency_proxy_feature_enabled })
      visit ci_cd_admin_application_settings_path
    end

    it 'allows you to change the virtual_registries_endpoints_api_limit setting' do
      within_testid('virtual-registries-form') do
        fill_in 'application_setting[virtual_registries_endpoints_api_limit]', with: 500
        click_button 'Save'
      end

      expect(current_settings.virtual_registries_endpoints_api_limit).to be 500
    end

    context 'when dependency_proxy feature is disabled' do
      let(:dependency_proxy_feature_enabled) { false }

      it 'does not display the virtual registry settings' do
        expect(page).not_to have_selector('[data-testid="virtual-registries-form"]')
      end
    end
  end

  describe 'sign up settings', :js, feature_category: :user_profile do
    before do
      visit general_admin_application_settings_path
    end

    it 'changes the user cap from unlimited to 5' do
      expect(current_settings.new_user_signups_cap).to be_nil

      page.within('#js-signup-settings') do
        find_by_testid('seat-control-user-cap').click
        fill_in 'application_setting[new_user_signups_cap]', with: 5

        click_button 'Save changes'

        expect(current_settings.new_user_signups_cap).to eq(5)
      end
    end

    context 'with a user cap assigned' do
      let(:seat_control_user_cap) { 1 }

      before do
        current_settings.update!(new_user_signups_cap: 5, seat_control: seat_control_user_cap)

        page.refresh
      end

      it 'changes the user cap to unlimited' do
        page.within('#js-signup-settings') do
          fill_in 'application_setting[new_user_signups_cap]', with: nil
          find_by_testid("seat-control-open-access").click

          click_button 'Save changes'

          expect(current_settings.new_user_signups_cap).to be_nil
        end
      end

      context 'with pending users' do
        before do
          create(:user, :blocked_pending_approval)
          visit general_admin_application_settings_path
        end

        it 'displays a modal confirmation when removing the cap' do
          page.within('#js-signup-settings') do
            fill_in 'application_setting[new_user_signups_cap]', with: nil
            find_by_testid("seat-control-open-access").click

            click_button 'Save changes'
          end

          page.within('.modal') do
            click_button 'Proceed and approve 1 user'
          end

          expect(current_settings.new_user_signups_cap).to be_nil
        end
      end

      context 'with form submit button confirmation modal for side-effect of possibly having overages' do
        active_user_count = 9

        let_it_be(:license) do
          create(:license, plan: License::ULTIMATE_PLAN, restrictions: { active_user_count: active_user_count })
        end

        before do
          current_user_cap_value = 5

          allow(License).to receive(:current).and_return(license)

          current_settings.update!(new_user_signups_cap: current_user_cap_value, seat_control: seat_control_user_cap)

          page.refresh
        end

        describe 'when user cap is higher than licensed users' do
          hihger_than_user_cap_value = 13

          it 'shows a modal' do
            within_testid('sign-up-restrictions-settings-content') do
              fill_in 'application_setting[new_user_signups_cap]', with: hihger_than_user_cap_value

              click_button 'Save changes'
            end

            within_modal do
              expect(page).to have_content "Changing the user cap to 13 would exceed the licensed user " \
                "count of 9, which may result in seat overages"
            end
          end
        end

        describe 'when user cap is higher lower licensed users' do
          lower_than_user_cap_value = 3

          it 'submits the form' do
            within_testid('sign-up-restrictions-settings-content') do
              fill_in 'application_setting[new_user_signups_cap]', with: lower_than_user_cap_value

              click_button 'Save changes'
            end

            expect(page).to have_content 'Application settings saved successfully'
          end
        end
      end
    end

    context 'for form submit button confirmation modal for side-effect of possibly adding unwanted new users' do
      using RSpec::Parameterized::TableSyntax

      where(:require_admin_approval_action, :user_cap_action, :add_pending_user, :button_effect) do
        :unchanged_true  | :unchanged                         | false | :submits_form
        :unchanged_false | :unchanged                         | false | :submits_form
        :toggled_off     | :unchanged                         | true  | :shows_confirmation_modal
        :toggled_off     | :unchanged                         | false | :submits_form
        :toggled_on      | :unchanged                         | false | :submits_form
        :unchanged_false | :increased                         | true  | :shows_confirmation_modal
        :unchanged_true  | :increased                         | false | :submits_form
        :toggled_off     | :increased                         | true  | :shows_confirmation_modal
        :toggled_off     | :increased                         | false | :submits_form
        :toggled_on      | :increased                         | true  | :shows_confirmation_modal
        :toggled_on      | :increased                         | false | :submits_form
        :toggled_on      | :decreased                         | false | :submits_form
        :toggled_on      | :decreased                         | true  | :submits_form
        :unchanged_false | :changed_from_limited_to_unlimited | true  | :shows_confirmation_modal
        :unchanged_false | :changed_from_limited_to_unlimited | false | :submits_form
        :unchanged_false | :changed_from_unlimited_to_limited | false | :submits_form
        :unchanged_false | :unchanged_unlimited               | false | :submits_form
      end

      with_them do
        it "handles form submission appropriately based on settings configuration" do
          user_cap_default = 5
          seat_control_user_cap = 1
          require_admin_approval_value = [:unchanged_true, :toggled_off].include?(require_admin_approval_action)

          current_settings.update_attribute(:require_admin_approval_after_user_signup, require_admin_approval_value)

          # rubocop:disable RSpec/AvoidConditionalStatements -- keeping the logic for readability
          unless [:changed_from_unlimited_to_limited, :unchanged_unlimited].include?(user_cap_action)
            current_settings.update!(new_user_signups_cap: user_cap_default, seat_control: seat_control_user_cap)
            page.refresh
          end

          if add_pending_user
            create(:user, :blocked_pending_approval)
            visit general_admin_application_settings_path
          end
          # rubocop:enable RSpec/AvoidConditionalStatements

          page.within('#js-signup-settings') do
            case require_admin_approval_action
            when :toggled_on
              find_by_testid('require-admin-approval-checkbox').set(true)
            when :toggled_off
              find_by_testid('require-admin-approval-checkbox').set(false)
            end

            case user_cap_action
            when :increased
              fill_in 'application_setting[new_user_signups_cap]', with: user_cap_default + 1
            when :decreased
              fill_in 'application_setting[new_user_signups_cap]', with: user_cap_default - 1
            when :changed_from_limited_to_unlimited
              fill_in 'application_setting[new_user_signups_cap]', with: nil
              find_by_testid("seat-control-open-access").click
            when :changed_from_unlimited_to_limited
              find_by_testid('seat-control-user-cap').click
              fill_in 'application_setting[new_user_signups_cap]', with: user_cap_default
            end

            click_button 'Save changes'
          end

          case button_effect
          when :shows_confirmation_modal
            expect(page).to have_selector('.modal')
            expect(page).to have_css('.modal .modal-body',
              text: 'By changing this setting, you can also automatically approve 1 user who is pending approval.')
          when :submits_form
            expect(page).to have_content 'Application settings saved successfully'
          end
        end
      end
    end
  end

  describe 'git abuse rate limit settings', :js, feature_category: :instance_resiliency do
    let(:license_allows) { true }
    let_it_be(:user) { create(:user) }

    before do
      stub_licensed_features(git_abuse_rate_limit: license_allows)

      visit reporting_admin_application_settings_path
    end

    context 'when license does not allow' do
      let(:license_allows) { false }

      it 'does not show the Git abuse rate limit section' do
        expect(page).not_to have_selector('[data-testid="git-abuse-rate-limit-settings"]')
      end
    end

    context 'when license allows' do
      it 'shows the Git abuse rate limit section' do
        expect(page).to have_selector('[data-testid="git-abuse-rate-limit-settings"]')
      end

      it 'shows the input fields' do
        expect(page).to have_field(s_('GitAbuse|Number of repositories'))
        expect(page).to have_field(s_('GitAbuse|Reporting time period (seconds)'))
        expect(page).to have_field(s_('GitAbuse|Excluded users'))
        expect(page).to have_selector(
          '[data-testid="auto-ban-users-toggle"] .gl-toggle-label',
          text: format(
            s_('GitAbuse|Automatically ban users from this %{scope} when they exceed the specified limits'),
            scope: 'application'
          )
        )
      end

      it 'saves the settings' do
        within_testid('git-abuse-rate-limit-settings') do
          fill_in(s_('GitAbuse|Number of repositories'), with: 5)
          fill_in(s_('GitAbuse|Reporting time period (seconds)'), with: 300)
          fill_in(s_('GitAbuse|Excluded users'), with: user.name)

          wait_for_requests

          click_button user.name
          within_testid('auto-ban-users-toggle') do
            find('.gl-toggle').click
          end

          click_button _('Save changes')
        end

        expect(page).to have_field(s_('GitAbuse|Number of repositories'), with: 5)
        expect(page).to have_field(s_('GitAbuse|Reporting time period (seconds)'), with: 300)
        expect(page).to have_content(user.name)
        expect(page).to have_selector('[data-testid="auto-ban-users-toggle"] .gl-toggle.is-checked')
      end

      it 'shows form errors when the input value is blank' do
        within_testid('git-abuse-rate-limit-settings') do
          fill_in(s_('GitAbuse|Number of repositories'), with: '')
          fill_in(s_('GitAbuse|Reporting time period (seconds)'), with: '')
          find('#reporting-time-period').native.send_keys :tab
        end

        expect(page).to have_content(s_("GitAbuse|Number of repositories can't be blank. Set to 0 for no limit."))
        expect(page).to have_content(s_("GitAbuse|Reporting time period can't be blank. Set to 0 for no limit."))
        expect(page).to have_button _('Save changes'), disabled: true
      end

      it 'shows form errors when the input value is greater than max' do
        page.within(find_by_testid('git-abuse-rate-limit-settings')) do
          fill_in(s_('GitAbuse|Number of repositories'), with: 10001)
          fill_in(s_('GitAbuse|Reporting time period (seconds)'), with: 864001)
          find('#reporting-time-period').native.send_keys :tab
        end

        expect(page).to have_content(
          format(s_('GitAbuse|Number of repositories should be between %{minNumRepos}-%{maxNumRepos}.'),
            minNumRepos: 0, maxNumRepos: 10000)
        )

        expect(page).to have_content(
          format(s_('GitAbuse|Reporting time period should be between %{minTimePeriod}-%{maxTimePeriod} seconds.'),
            minTimePeriod: 0, maxTimePeriod: 864000)
        )
        expect(page).to have_button _('Save changes'), disabled: true
      end
    end
  end

  describe 'SCIM token', feature_category: :system_access do
    context 'when the feature is not licensed' do
      before do
        stub_licensed_features(instance_level_scim: false)
        visit general_admin_application_settings_path
      end

      it 'does not display the section when not licensed' do
        expect(page).not_to have_content(s_('SCIM|SCIM Token'))
      end
    end

    context 'when the feature is licensed' do
      before do
        stub_licensed_features(instance_level_scim: true)
        visit general_admin_application_settings_path
      end

      it 'displays the section', :js, :aggregate_failures do
        expect(page).to have_content(s_('SCIM|SCIM Token'))

        click_button s_('GroupSAML|Generate a SCIM token')
        expect(page).to have_content s_('GroupSaml|Your SCIM token')
        expect(page).to have_content s_('GroupSaml|SCIM API endpoint URL')
      end
    end
  end

  describe 'Microsoft Azure integration', feature_category: :system_access do
    before do
      allow(::Gitlab::Auth::Saml::Config).to receive(:microsoft_group_sync_enabled?).and_return(true)
    end

    it_behaves_like 'Microsoft Azure integration form' do
      let(:path) { general_admin_application_settings_path }
    end
  end

  describe 'Namespace storage cost factor for forks setting', feature_category: :consumables_cost_management do
    context 'when checking namespace plans' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      it 'saves the cost factor for forks' do
        visit namespace_storage_admin_application_settings_path

        fill_in 'Cost factor for forks of projects', with: '0.008'

        click_button 'Save changes'

        expect(page).to have_content 'Application settings saved successfully'
        expect(page).to have_field 'Cost factor for forks of projects', with: '0.008'
      end

      it 'shows an error when the cost factor is out of range' do
        visit namespace_storage_admin_application_settings_path

        fill_in 'Cost factor for forks of projects', with: '2.0'

        click_button 'Save changes'

        expect(page).to have_content 'Application settings update failed'
        expect(page).to have_content 'Namespace storage forks cost factor must be less than or equal to 1'
      end
    end
  end

  def current_settings
    ApplicationSetting.current_without_cache
  end
end
