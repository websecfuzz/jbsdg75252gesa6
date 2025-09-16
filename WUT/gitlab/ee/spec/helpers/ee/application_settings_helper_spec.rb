# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::ApplicationSettingsHelper, feature_category: :shared do
  include Devise::Test::ControllerHelpers
  describe '.visible_attributes' do
    it 'contains personal access token parameters' do
      expect(visible_attributes).to include(*%i[max_personal_access_token_lifetime])
    end

    it 'contains duo_features_enabled parameters' do
      expect(visible_attributes)
        .to include(*%i[duo_features_enabled lock_duo_features_enabled duo_availability enabled_expanded_logging])
    end

    it 'contains search parameters' do
      expected_fields = %i[
        global_search_code_enabled
        global_search_commits_enabled
        global_search_wiki_enabled
        global_search_epics_enabled
        global_search_snippet_titles_enabled
        global_search_users_enabled
        global_search_issues_enabled
        global_search_merge_requests_enabled
        global_search_block_anonymous_searches_enabled
        global_search_limited_indexing_enabled
        elastic_migration_worker_enabled
        anonymous_searches_allowed
      ]
      expect(helper.visible_attributes).to include(*expected_fields)
    end

    it 'contains zoekt parameters' do
      expected_fields = ::Search::Zoekt::Settings.all_settings.keys
      expect(visible_attributes).to include(*expected_fields)
    end

    it 'contains member_promotion_management parameters' do
      expect(visible_attributes).to include(*%i[enable_member_promotion_management])
    end

    context 'when identity verification is enabled' do
      before do
        stub_saas_features(identity_verification: true)
      end

      it 'contains identity verification related attributes' do
        expect(visible_attributes).to include(*%i[
          arkose_labs_client_secret
          arkose_labs_client_xid
          arkose_labs_enabled
          arkose_labs_data_exchange_enabled
          arkose_labs_namespace
          arkose_labs_private_api_key
          arkose_labs_public_api_key
          ci_requires_identity_verification_on_free_plan
          credit_card_verification_enabled
          phone_verification_enabled
          telesign_customer_xid
          telesign_api_key
        ])
      end
    end

    context 'when identity verification is not enabled' do
      it 'does not contain identity verification related attributes' do
        expect(visible_attributes).not_to include(*%i[
          arkose_labs_client_secret
          arkose_labs_client_xid
          arkose_labs_enabled
          arkose_labs_data_exchange_enabled
          arkose_labs_namespace
          arkose_labs_private_api_key
          arkose_labs_public_api_key
          ci_requires_identity_verification_on_free_plan
          credit_card_verification_enabled
          phone_verification_enabled
          telesign_customer_xid
          telesign_api_key
        ])
      end
    end
  end

  describe '.possible_licensed_attributes' do
    %i[
      secret_push_protection_available
      virtual_registries_endpoints_api_limit
      disable_invite_members
    ].each do |setting|
      it "contains #{setting}" do
        expect(described_class.possible_licensed_attributes).to include(setting)
      end
    end
  end

  describe '.registration_features_can_be_prompted?' do
    subject { helper.registration_features_can_be_prompted? }

    context 'without a valid license' do
      before do
        allow(License).to receive(:current).and_return(nil)
      end

      context 'when service ping is enabled' do
        before do
          stub_application_setting(usage_ping_enabled: true)
        end

        it { is_expected.to be_falsey }
      end

      context 'when service ping is disabled' do
        before do
          stub_application_setting(usage_ping_enabled: false)
        end

        it { is_expected.to be_truthy }
      end
    end

    context 'with a license' do
      let(:license) { build(:license) }

      before do
        allow(License).to receive(:current).and_return(license)
      end

      it { is_expected.to be_falsey }

      context 'when service ping is disabled' do
        before do
          stub_application_setting(usage_ping_enabled: false)
        end

        it { is_expected.to be_falsey }
      end
    end
  end

  describe '.signup_form_data' do
    let_it_be(:application_setting) { build(:application_setting) }
    let_it_be(:current_user) { build_stubbed(:admin) }
    let(:promotion_management_available) { true }

    before do
      allow(helper).to receive(:member_promotion_management_feature_available?)
        .and_return(promotion_management_available)
      application_setting.enable_member_promotion_management = true
      helper.instance_variable_set(:@application_setting, application_setting)
    end

    subject { helper.signup_form_data }

    describe 'Promotion management' do
      it 'sets promotion_management_available and enable_member_promotion_management values' do
        is_expected.to match(hash_including({
          promotion_management_available: promotion_management_available.to_s,
          enable_member_promotion_management: true.to_s,
          can_disable_member_promotion_management: true.to_s,
          role_promotion_requests_path: '/admin/role_promotion_requests'
        }))
      end

      context 'when promotion management is unavailable' do
        let(:promotion_management_available) { false }

        it 'includes promotion_management_available as false' do
          is_expected.to match(hash_including({ promotion_management_available: promotion_management_available.to_s }))
        end

        it { is_expected.to match(hash_excluding(:enable_member_promotion_management)) }
      end
    end

    describe 'Licensed user count' do
      it { is_expected.to match(hash_including({ licensed_user_count: '' })) }

      context 'with a license' do
        let(:seats) { 10 }

        before do
          create_current_license(plan: License::ULTIMATE_PLAN, seats: seats)
        end

        it { is_expected.to match(hash_including({ licensed_user_count: seats.to_s })) }
      end
    end

    describe 'Seat control' do
      it { is_expected.to match(hash_including({ seat_control: ApplicationSetting::SEAT_CONTROL_OFF.to_s })) }

      context 'when the feature is not available' do
        before do
          stub_licensed_features(seat_control: false)
        end

        it { is_expected.to match(hash_including({ seat_control: '' })) }
      end
    end
  end

  describe '.git_abuse_rate_limit_data', feature_category: :insider_threat do
    let_it_be(:application_setting) { build(:application_setting) }

    before do
      application_setting.max_number_of_repository_downloads = 1
      application_setting.max_number_of_repository_downloads_within_time_period = 2
      application_setting.git_rate_limit_users_allowlist = %w[username1 username2]
      application_setting.git_rate_limit_users_alertlist = [3, 4]
      application_setting.auto_ban_user_on_excessive_projects_download = true

      helper.instance_variable_set(:@application_setting, application_setting)
    end

    subject { helper.git_abuse_rate_limit_data }

    it 'returns the expected data' do
      is_expected.to eq({ max_number_of_repository_downloads: 1,
                          max_number_of_repository_downloads_within_time_period: 2,
                          git_rate_limit_users_allowlist: %w[username1 username2],
                          git_rate_limit_users_alertlist: [3, 4],
                          auto_ban_user_on_excessive_projects_download: 'true' })
    end
  end

  describe '#sync_purl_types_checkboxes', feature_category: :software_composition_analysis do
    let_it_be(:application_setting) { build(:application_setting) }
    let_it_be(:enabled_purl_types) { [1, 5] }

    before do
      application_setting.package_metadata_purl_types = enabled_purl_types

      helper.instance_variable_set(:@application_setting, application_setting)
    end

    it 'returns correctly checked purl type checkboxes' do
      helper.gitlab_ui_form_for(application_setting,
        url: '/admin/application_settings/security_and_compliance') do |form|
        result = helper.sync_purl_types_checkboxes(form)

        expected = ::Enums::Sbom.purl_types.map do |name, num|
          if enabled_purl_types.include?(num)
            have_checked_field(name, with: num)
          else
            have_unchecked_field(name, with: num)
          end
        end

        expect(result).to match_array(expected)
      end
    end
  end

  describe '#global_search_settings_checkboxes', feature_category: :global_search do
    let_it_be(:application_setting) { build(:application_setting) }

    context 'when license is enabled' do
      before do
        stub_licensed_features(elastic_search: true)
        application_setting.global_search_issues_enabled = true
        application_setting.global_search_merge_requests_enabled = false
        application_setting.global_search_snippet_titles_enabled = true
        application_setting.global_search_users_enabled = false
        application_setting.global_search_code_enabled = true
        application_setting.global_search_commits_enabled = false
        application_setting.global_search_epics_enabled = true
        application_setting.global_search_wiki_enabled = true
        application_setting.global_search_block_anonymous_searches_enabled = false
        helper.instance_variable_set(:@application_setting, application_setting)
      end

      it 'returns correctly checked checkboxes' do
        helper.gitlab_ui_form_for(application_setting, url: search_admin_application_settings_path) do |form|
          result = helper.global_search_settings_checkboxes(form)
          expect(result[0]).to have_checked_field('Allow unauthenticated users to use search', with: 1)
          expect(result[1]).not_to have_checked_field('Restrict global search to authenticated users only', with: 1)
          expect(result[2]).to have_checked_field('Show issues in global search results', with: 1)
          expect(result[3]).not_to have_checked_field('Show merge requests in global search results', with: 1)
          expect(result[4]).to have_checked_field('Show snippets in global search results', with: 1)
          expect(result[5]).not_to have_checked_field('Show users in global search results', with: 1)
          expect(result[6]).to have_checked_field('Show code in global search results', with: 1)
          expect(result[7]).not_to have_checked_field('Show commits in global search results', with: 1)
          expect(result[8]).to have_checked_field('Show epics in global search results', with: 1)
          expect(result[9]).to have_checked_field('Show wikis in global search results', with: 1)
        end
      end
    end

    context 'when license is disabled' do
      before do
        stub_licensed_features(elastic_search: false)
        application_setting.global_search_issues_enabled = true
        application_setting.global_search_merge_requests_enabled = false
        application_setting.global_search_users_enabled = false
        application_setting.global_search_snippet_titles_enabled = true
        application_setting.global_search_block_anonymous_searches_enabled = true
        helper.instance_variable_set(:@application_setting, application_setting)
      end

      it 'returns correctly checked checkboxes' do
        helper.gitlab_ui_form_for(application_setting, url: search_admin_application_settings_path) do |form|
          result = helper.global_search_settings_checkboxes(form)
          expect(result[0]).to have_checked_field('Allow unauthenticated users to use search', with: 1)
          expect(result[1]).to have_checked_field('Restrict global search to authenticated users only', with: 1)
          expect(result[2]).to have_checked_field('Show issues in global search results', with: 1)
          expect(result[3]).not_to have_checked_field('Show merge requests in global search results', with: 1)
          expect(result[4]).to have_checked_field('Show snippets in global search results', with: 1)
          expect(result[5]).not_to have_checked_field('Show users in global search results', with: 1)
        end
      end
    end
  end

  describe '#vscode_extension_marketplace_settings_description' do
    using RSpec::Parameterized::TableSyntax

    subject(:description) { helper.vscode_extension_marketplace_settings_description }

    where(:remote_dev_license, :expected_description) do
      false | _('Enable VS Code Extension Marketplace and configure the extensions registry for Web IDE.')
      true  | _('Enable VS Code Extension Marketplace and configure the extensions registry for Web IDE and Workspaces.') # rubocop:disable -- The message extends past the line length
    end

    with_them do
      before do
        stub_licensed_features(remote_development: remote_dev_license)
      end

      it { is_expected.to be(expected_description) }
    end
  end

  describe '#zoekt_settings_checkboxes', feature_category: :global_search do
    let_it_be(:application_setting) { build(:application_setting) }

    before do
      application_setting.zoekt_lost_node_threshold = Search::Zoekt::Settings::DEFAULT_LOST_NODE_THRESHOLD
      application_setting.zoekt_auto_index_root_namespace = false
      application_setting.zoekt_indexing_enabled = true
      application_setting.zoekt_indexing_paused = false
      application_setting.zoekt_search_enabled = true
      helper.instance_variable_set(:@application_setting, application_setting)
    end

    it 'returns correctly checked checkboxes' do
      helper.gitlab_ui_form_for(application_setting, url: search_admin_application_settings_path) do |form|
        result = helper.zoekt_settings_checkboxes(form)
        expect(result[0]).to have_checked_field('Enable indexing', with: 1)
        expect(result[1]).to have_checked_field('Enable searching', with: 1)
        expect(result[2]).not_to have_checked_field('Pause indexing', with: 1)
        expect(result[3]).not_to have_checked_field('Index root namespaces automatically', with: 1)
        expect(result[4]).to have_checked_field(
          format(_("Cache search results for %{label}"), label: ::Search::Zoekt::Cache.humanize_expires_in), with: 1
        )
      end
    end
  end

  describe '#zoekt_settings_inputs', feature_category: :global_search do
    let_it_be(:application_setting) { build(:application_setting) }

    before do
      application_setting.zoekt_cpu_to_tasks_ratio = 1.5
      application_setting.zoekt_rollout_batch_size = 100
      application_setting.zoekt_lost_node_threshold = '12h'
      helper.instance_variable_set(:@application_setting, application_setting)
    end

    it 'returns correct inputs' do
      helper.gitlab_ui_form_for(application_setting, url: search_admin_application_settings_path) do |form|
        result = helper.zoekt_settings_inputs(form)
        expect(result[0]).to have_selector('label', text: 'Indexing CPU to tasks multiplier')
        expect(result[1])
          .to have_selector('input[type="number"][name="application_setting[zoekt_cpu_to_tasks_ratio]"][value="1.5"]')
        expect(result[2]).to have_selector('label', text: _('Number of parallel processes per indexing task'))
        expect(result[3])
          .to have_selector('input[type="number"][name="application_setting[zoekt_indexing_parallelism]"][value="1"]')
        expect(result[4]).to have_selector('label', text: _('Number of namespaces per indexing rollout'))
        expect(result[5])
          .to have_selector('input[type="number"][name="application_setting[zoekt_rollout_batch_size]"][value="100"]')
        expect(result[6]).to have_selector('label', text: _('Offline nodes automatically deleted after'))
        selector = 'input[type="text"][name="application_setting[zoekt_lost_node_threshold]"]' \
          "[value=\"#{Search::Zoekt::Settings::DEFAULT_LOST_NODE_THRESHOLD}\"]"
        expect(result[7]).to have_selector(selector)
        expect(result[8]).to have_selector('label', text: _('Indexing timeout per project'))
        selector = 'input[type="text"][name="application_setting[zoekt_indexing_timeout]"]' \
          "[value=\"#{Search::Zoekt::Settings::DEFAULT_INDEXING_TIMEOUT}\"]"
        expect(result[9]).to have_selector(selector)
        expect(result[10]).to have_selector('label', text: _('Maximum number of files per project to be indexed'))
        selector = 'input[type="number"][name="application_setting[zoekt_maximum_files]"]' \
          "[value=\"#{Search::Zoekt::Settings::DEFAULT_MAXIMUM_FILES}\"]"
        expect(result[11]).to have_selector(selector)
        expect(result[12]).to have_selector('label', text: _('Retry interval for failed namespaces'))
        selector = 'input[type="text"][name="application_setting[zoekt_rollout_retry_interval]"]' \
          "[value=\"#{Search::Zoekt::Settings::DEFAULT_ROLLOUT_RETRY_INTERVAL}\"]"
        expect(result[13]).to have_selector(selector)
      end
    end

    context 'with custom input options' do
      before do
        allow(::Search::Zoekt::Settings).to receive(:input_settings).and_return({
          zoekt_cpu_to_tasks_ratio: {
            label: -> { 'Custom Label' },
            input_type: :number_field,
            input_options: { min: 0, max: 10, step: 0.1 }
          }
        })
      end

      it 'includes the custom input options' do
        helper.gitlab_ui_form_for(application_setting, url: search_admin_application_settings_path) do |form|
          result = helper.zoekt_settings_inputs(form)
          expect(result[0]).to have_selector('label', text: 'Custom Label')
          expect(result[1]).to have_selector('input[type="number"][min="0"][max="10"][step="0.1"]')
        end
      end
    end

    context 'with an unknown input type' do
      before do
        # Mock Search::Zoekt::Settings to return our test configuration
        allow(::Search::Zoekt::Settings).to receive(:input_settings).and_return({
          zoekt_test_setting: {
            label: -> { "Test Setting" },
            input_type: :unknown_type
          }
        })

        # Make application_setting respond to our test setting
        allow(application_setting).to receive(:zoekt_test_setting).and_return(42)
      end

      it 'raises an ArgumentError for unknown input types' do
        # Use a real form builder
        helper.gitlab_ui_form_for(application_setting, url: search_admin_application_settings_path) do |form|
          # This should execute the actual method including line 319
          expect { helper.zoekt_settings_inputs(form) }.to raise_error(ArgumentError, /Unknown input_type:/)
        end
      end
    end
  end

  describe '#identity_verification_attributes', feature_category: :user_management do
    subject { helper.send(:identity_verification_attributes) }

    context 'when identity verification is available' do
      before do
        stub_saas_features(identity_verification: true)
      end

      it 'returns the identity verification attributes' do
        is_expected.to contain_exactly(
          :arkose_labs_client_secret,
          :arkose_labs_client_xid,
          :arkose_labs_enabled,
          :arkose_labs_data_exchange_enabled,
          :arkose_labs_namespace,
          :arkose_labs_private_api_key,
          :arkose_labs_public_api_key,
          :ci_requires_identity_verification_on_free_plan,
          :credit_card_verification_enabled,
          :phone_verification_enabled,
          :telesign_api_key,
          :telesign_customer_xid
        )
      end
    end

    context 'when identity verification is not available' do
      before do
        stub_saas_features(identity_verification: false)
      end

      it 'returns an empty array' do
        is_expected.to eq([])
      end
    end
  end

  describe '#enable_promotion_management_attributes', feature_category: :user_management do
    subject { helper.send(:enable_promotion_management_attributes) }

    context 'when gitlab_com_subscriptions feature is available' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      it 'returns an empty array' do
        is_expected.to eq([])
      end
    end

    context 'when gitlab_com_subscriptions feature is not available' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      it 'returns the promotion management attributes' do
        is_expected.to contain_exactly(:enable_member_promotion_management)
      end
    end
  end

  describe '#compliance_security_policy_group_id' do
    subject { helper.compliance_security_policy_group_id }

    before do
      allow(Security::PolicySetting).to receive(:for_organization).and_return(policy_setting)
    end

    context 'when CSP group is not set' do
      let(:policy_setting) { build_stubbed(:security_policy_settings, csp_namespace: nil) }

      it { is_expected.to be_nil }
    end

    context 'when CSP group is set' do
      let(:csp_group) { build_stubbed(:group) }
      let(:policy_setting) { build_stubbed(:security_policy_settings, csp_namespace: csp_group) }

      it { is_expected.to eq(csp_group.id) }
    end
  end
end
