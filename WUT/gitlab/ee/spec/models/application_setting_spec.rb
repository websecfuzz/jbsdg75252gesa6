# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ApplicationSetting, feature_category: :shared, type: :model do
  using RSpec::Parameterized::TableSyntax

  subject(:setting) { described_class.create_from_defaults }

  describe 'cyclical dependency ApplicationSetting <-> License' do
    before do
      described_class.delete_all # ensure no records exist
    end

    it 'does not depend on License.feature_available? check on creation' do
      expect(License).not_to receive(:feature_available?)
      described_class.create_from_defaults
    end
  end

  describe 'default values' do
    context 'with ELASTIC_URL environment variable set' do
      let(:elastic_url) { 'http://elastic:12345' }

      before do
        stub_env('ELASTIC_URL', elastic_url)
      end

      it { expect(setting.elasticsearch_url).to eq([URI.parse(elastic_url)]) }
    end

    describe 'elasticsearch jsonb_accessor fields with defaults' do
      it 'ensures all elasticsearch fields with defaults are included in .defaults', :aggregate_failures do
        # Get elasticsearch jsonb_accessor fields
        elasticsearch_fields_with_defaults = described_class.jsonb_defaults_mapping_for_elasticsearch

        defaults = described_class.defaults

        # Check that each elasticsearch field with a default is included in ApplicationSetting.defaults
        elasticsearch_fields_with_defaults.each do |field, expected_default|
          field_symbol = field.to_sym
          expect(defaults[field_symbol]).to eq(expected_default),
            "Expected '#{field}' default to be #{expected_default} but got #{defaults[field_symbol].inspect}"
        end
      end
    end

    it 'has correct default values' do
      is_expected.to have_attributes(
        allow_all_integrations: true,
        allow_group_owners_to_manage_ldap: true,
        allowed_integrations: [],
        anonymous_searches_allowed: true,
        arkose_labs_data_exchange_enabled: true,
        arkose_labs_enabled: true,
        auto_ban_user_on_excessive_projects_download: false,
        automatic_purchased_storage_allocation: false,
        ci_requires_identity_verification_on_free_plan: true,
        credit_card_verification_enabled: true,
        cube_api_base_url: nil,
        cube_api_key: nil,
        custom_project_templates_group_id: nil,
        dashboard_limit: 0,
        dashboard_limit_enabled: false,
        default_project_deletion_protection: false,
        disable_invite_members: false,
        disable_personal_access_tokens: false,
        disabled_direct_code_suggestions: false,
        duo_chat_expiration_column: 'last_updated_at',
        duo_chat_expiration_days: 30,
        duo_workflow_oauth_application_id: nil,
        elastic_migration_worker_enabled: true,
        elasticsearch_analyzers_kuromoji_enabled: false,
        elasticsearch_analyzers_kuromoji_search: false,
        elasticsearch_analyzers_smartcn_enabled: false,
        elasticsearch_analyzers_smartcn_search: false,
        elasticsearch_aws: false,
        elasticsearch_aws_access_key: nil,
        elasticsearch_aws_region: 'us-east-1',
        elasticsearch_aws_role_arn: nil,
        elasticsearch_aws_secret_access_key: nil,
        elasticsearch_client_request_timeout: 0,
        elasticsearch_indexed_field_length_limit: 0,
        elasticsearch_indexed_file_size_limit_kb: 1024,
        elasticsearch_indexing: false,
        elasticsearch_limit_indexing: false,
        elasticsearch_max_bulk_concurrency: 10,
        elasticsearch_max_bulk_size_mb: 10,
        elasticsearch_max_code_indexing_concurrency: 30,
        elasticsearch_password: nil,
        elasticsearch_pause_indexing: false,
        elasticsearch_prefix: 'gitlab',
        elasticsearch_requeue_workers: false,
        elasticsearch_retry_on_failure: 0,
        elasticsearch_search: false,
        elasticsearch_username: nil,
        elasticsearch_worker_number_of_shards: 2,
        email_additional_text: nil,
        enforce_namespace_storage_limit: false,
        fetch_observability_alerts_from_cloud: true,
        future_subscriptions: [],
        geo_node_allowed_ips: '0.0.0.0/0, ::/0',
        git_rate_limit_users_alertlist: [],
        git_rate_limit_users_allowlist: [],
        git_two_factor_session_expiry: 15,
        global_search_block_anonymous_searches_enabled: false,
        global_search_code_enabled: true,
        global_search_commits_enabled: true,
        global_search_epics_enabled: true,
        global_search_issues_enabled: true,
        global_search_limited_indexing_enabled: false,
        global_search_merge_requests_enabled: true,
        global_search_snippet_titles_enabled: true,
        global_search_users_enabled: true,
        global_search_wiki_enabled: true,
        globally_allowed_ips: '',
        hard_phone_verification_transactions_daily_limit: 20_000,
        instance_level_ai_beta_features_enabled: false,
        license_usage_data_exported: false,
        lock_memberships_to_ldap: false,
        lock_memberships_to_saml: false,
        maintenance_mode: false,
        max_number_of_repository_downloads: 0,
        max_number_of_repository_downloads_within_time_period: 0,
        max_personal_access_token_lifetime: nil,
        max_ssh_key_lifetime: nil,
        mirror_capacity_threshold: Settings.gitlab['mirror_capacity_threshold'],
        mirror_max_capacity: Settings.gitlab['mirror_max_capacity'],
        mirror_max_delay: Settings.gitlab['mirror_max_delay'],
        phone_verification_enabled: true,
        pipeline_execution_policies_per_configuration_limit: 5,
        product_analytics_configurator_connection_string: nil,
        product_analytics_data_collector_host: nil,
        product_analytics_enabled: false,
        receptive_cluster_agents_enabled: false,
        repository_size_limit: 0,
        scan_execution_policies_action_limit: 0,
        scan_execution_policies_schedule_limit: 0,
        seat_control: 0,
        secret_detection_revocation_token_types_url: nil,
        secret_detection_service_auth_token: nil,
        secret_detection_service_url: '',
        secret_detection_token_revocation_enabled: false,
        secret_detection_token_revocation_token: nil,
        secret_detection_token_revocation_url: nil,
        security_approval_policies_limit: 5,
        soft_phone_verification_transactions_daily_limit: 16_000,
        telesign_intelligence_enabled: true,
        unverified_account_group_creation_limit: 2,
        virtual_registries_endpoints_api_limit: 1000,
        zoekt_auto_index_root_namespace: false,
        zoekt_cache_response: true,
        zoekt_cpu_to_tasks_ratio: 1.0,
        zoekt_indexing_enabled: false,
        zoekt_indexing_parallelism: 1,
        zoekt_indexing_paused: false,
        zoekt_rollout_batch_size: 32,
        zoekt_rollout_retry_interval: Search::Zoekt::Settings::DEFAULT_ROLLOUT_RETRY_INTERVAL,
        zoekt_lost_node_threshold: Search::Zoekt::Settings::DEFAULT_LOST_NODE_THRESHOLD,
        zoekt_search_enabled: false,
        enforce_pipl_compliance: true
      )
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:file_template_project).class_name('Project') }
  end

  describe 'validations' do
    describe 'mirror', feature_category: :source_code_management do
      it { is_expected.to validate_numericality_of(:mirror_max_delay).only_integer }
      it { is_expected.not_to allow_value(nil).for(:mirror_max_delay) }
      it { is_expected.not_to allow_value(0).for(:mirror_max_delay) }
      it { is_expected.not_to allow_value((Gitlab::Mirror::MIN_DELAY - 1.minute) / 60).for(:mirror_max_delay) }

      it { is_expected.to validate_numericality_of(:mirror_max_capacity).only_integer.is_greater_than(0) }
      it { is_expected.not_to allow_value(nil).for(:mirror_max_capacity) }

      it { is_expected.to validate_numericality_of(:mirror_capacity_threshold).only_integer.is_greater_than(0) }
      it { is_expected.not_to allow_value(nil).for(:mirror_capacity_threshold) }
      it { is_expected.not_to allow_value(setting.mirror_max_capacity + 1).for(:mirror_capacity_threshold) }
      it { is_expected.to allow_value(nil).for(:custom_project_templates_group_id) }

      it { is_expected.not_to allow_value(nil).for(:observability_backend_ssl_verification_enabled) }
    end

    describe 'security_and_compliance_setting jsonb_column`s atrributes', feature_category: :compliance_management do
      it { is_expected.to allow_values([true, false]).for(:enforce_pipl_compliance) }
    end

    describe 'elasticsearch', feature_category: :global_search do
      it { is_expected.to validate_numericality_of(:search_max_shard_size_gb).only_integer.is_greater_than(0) }
      it { is_expected.not_to allow_value(nil).for(:search_max_shard_size_gb) }

      it { is_expected.to validate_numericality_of(:search_max_docs_denominator).only_integer.is_greater_than(0) }
      it { is_expected.not_to allow_value(nil).for(:search_max_docs_denominator) }

      it { is_expected.to validate_numericality_of(:search_min_docs_before_rollover).only_integer.is_greater_than(0) }
      it { is_expected.not_to allow_value(nil).for(:search_min_docs_before_rollover) }

      it 'validates elasticsearch_worker_number_of_shards' do
        is_expected.to validate_numericality_of(:elasticsearch_worker_number_of_shards).only_integer.is_greater_than(0)
          .is_less_than_or_equal_to(Elastic::ProcessBookkeepingService::SHARDS_MAX)
      end

      it { is_expected.not_to allow_value(nil).for(:elasticsearch_worker_number_of_shards) }

      it 'validates elasticsearch_indexed_file_size_limit_kb' do
        is_expected.to validate_numericality_of(:elasticsearch_indexed_file_size_limit_kb)
          .only_integer.is_greater_than(0)
      end

      it { is_expected.not_to allow_value(nil).for(:elasticsearch_indexed_file_size_limit_kb) }

      it 'validates elasticsearch_indexed_field_length_limit' do
        is_expected.to validate_numericality_of(:elasticsearch_indexed_field_length_limit)
          .only_integer.is_greater_than_or_equal_to(0)
      end

      it { is_expected.not_to allow_value(nil).for(:elasticsearch_indexed_field_length_limit) }

      it { is_expected.to validate_numericality_of(:elasticsearch_max_bulk_size_mb).only_integer.is_greater_than(0) }
      it { is_expected.not_to allow_value(nil).for(:elasticsearch_max_bulk_size_mb) }

      it 'validates elasticsearch_max_bulk_concurrency' do
        is_expected.to validate_numericality_of(:elasticsearch_max_bulk_concurrency)
          .only_integer.is_greater_than(0)
      end

      it { is_expected.not_to allow_value(nil).for(:elasticsearch_max_bulk_concurrency) }

      it 'validates elasticsearch_client_request_timeout' do
        is_expected.to validate_numericality_of(:elasticsearch_client_request_timeout)
          .only_integer.is_greater_than_or_equal_to(0)
      end

      it { is_expected.to allow_value(2).for(:elasticsearch_max_code_indexing_concurrency) }
      it { is_expected.to allow_value(0).for(:elasticsearch_max_code_indexing_concurrency) }
      it { is_expected.not_to allow_value(-1).for(:elasticsearch_max_code_indexing_concurrency) }
      it { is_expected.not_to allow_value(nil).for(:elasticsearch_max_code_indexing_concurrency) }
      it { is_expected.not_to allow_value(1.1).for(:elasticsearch_max_code_indexing_concurrency) }

      it { is_expected.to allow_value(30).for(:elasticsearch_client_request_timeout) }
      it { is_expected.to allow_value(0).for(:elasticsearch_client_request_timeout) }
      it { is_expected.not_to allow_value(nil).for(:elasticsearch_client_request_timeout) }

      it { is_expected.to allow_value(30).for(:elasticsearch_retry_on_failure) }
      it { is_expected.to allow_value(0).for(:elasticsearch_retry_on_failure) }
      it { is_expected.not_to allow_value(-1).for(:elasticsearch_retry_on_failure) }
      it { is_expected.not_to allow_value(nil).for(:elasticsearch_retry_on_failure) }

      it { is_expected.to allow_value('').for(:elasticsearch_username) }
      it { is_expected.to allow_value('a' * 255).for(:elasticsearch_username) }
      it { is_expected.not_to allow_value('a' * 256).for(:elasticsearch_username) }

      describe 'elasticsearch_prefix validation' do
        it { is_expected.to allow_value('gitlab').for(:elasticsearch_prefix) }
        it { is_expected.to allow_value('custom-prefix').for(:elasticsearch_prefix) }
        it { is_expected.to allow_value('my_prefix').for(:elasticsearch_prefix) }
        it { is_expected.to allow_value('prefix123').for(:elasticsearch_prefix) }
        it { is_expected.to allow_value('a').for(:elasticsearch_prefix) }
        it { is_expected.to allow_value('1').for(:elasticsearch_prefix) }
        it { is_expected.to allow_value('a1b2c3').for(:elasticsearch_prefix) }

        it { is_expected.not_to allow_value('').for(:elasticsearch_prefix) }
        it { is_expected.not_to allow_value(nil).for(:elasticsearch_prefix) }
        it { is_expected.not_to allow_value('Prefix').for(:elasticsearch_prefix) }
        it { is_expected.not_to allow_value('-prefix').for(:elasticsearch_prefix) }
        it { is_expected.not_to allow_value('prefix-').for(:elasticsearch_prefix) }
        it { is_expected.not_to allow_value('_prefix').for(:elasticsearch_prefix) }
        it { is_expected.not_to allow_value('prefix_').for(:elasticsearch_prefix) }
        it { is_expected.not_to allow_value('prefix with spaces').for(:elasticsearch_prefix) }
        it { is_expected.not_to allow_value(' prefix').for(:elasticsearch_prefix) }
        it { is_expected.not_to allow_value('prefix ').for(:elasticsearch_prefix) }
        it { is_expected.not_to allow_value('prefix@special').for(:elasticsearch_prefix) }
        it { is_expected.not_to allow_value('prefix.dot').for(:elasticsearch_prefix) }
        it { is_expected.not_to allow_value('a' * 101).for(:elasticsearch_prefix) }
      end
    end

    describe '#sdrs_jwt_signing_key' do
      let(:rsa_key) { OpenSSL::PKey::RSA.generate(2048) }
      let(:setting) { build(:application_setting) }

      it { is_expected.to allow_value(nil).for(:sdrs_jwt_signing_key) }
      it { is_expected.to allow_value(rsa_key.to_pem).for(:sdrs_jwt_signing_key) }

      it 'encrypts and decrypts the value' do
        setting.sdrs_jwt_signing_key = rsa_key.to_pem
        setting.save!

        # Verify encryption
        encrypted_value = described_class.connection.select_value(
          "SELECT sdrs_jwt_signing_key FROM application_settings WHERE id = #{setting.id}"
        )
        expect(encrypted_value).not_to include(rsa_key.to_pem)

        # Verify decryption
        setting.reload
        expect(setting.sdrs_jwt_signing_key).to eq(rsa_key.to_pem)
      end
    end

    describe 'security policy settings' do
      it 'validates security_approval_policies_limit' do
        is_expected.to validate_numericality_of(:security_approval_policies_limit)
                         .only_integer
                         .is_greater_than_or_equal_to(5)
                         .is_less_than_or_equal_to(::Security::ScanResultPolicy::POLICIES_LIMIT)
      end

      it 'validates scan_execution_policies_action_limit' do
        is_expected.to validate_numericality_of(:scan_execution_policies_action_limit)
                         .only_integer
                         .is_greater_than_or_equal_to(0)
                         .is_less_than_or_equal_to(20)
      end

      it 'validates scan_execution_policies_schedule_limit' do
        is_expected.to validate_numericality_of(:scan_execution_policies_schedule_limit)
                         .only_integer
                         .is_greater_than_or_equal_to(0)
                         .is_less_than_or_equal_to(20)
      end
    end

    describe 'identity_verification_settings' do
      %i[
        soft_phone_verification_transactions_daily_limit
        hard_phone_verification_transactions_daily_limit
        unverified_account_group_creation_limit
      ].each do |field|
        it_behaves_like 'validates jsonb integer field', field, :identity_verification_settings
      end

      %i[
        phone_verification_enabled
        ci_requires_identity_verification_on_free_plan
        telesign_intelligence_enabled
        credit_card_verification_enabled
        arkose_labs_enabled
        arkose_labs_data_exchange_enabled
      ].each do |field|
        it_behaves_like 'validates jsonb boolean field', field, :identity_verification_settings
      end
    end

    describe 'future_subscriptions', feature_category: :subscription_management do
      it { is_expected.to allow_value([{}]).for(:future_subscriptions) }
      it { is_expected.not_to allow_value({}).for(:future_subscriptions) }
      it { is_expected.not_to allow_value(nil).for(:future_subscriptions) }
    end

    describe 'required_instance', feature_category: :pipeline_composition do
      it { is_expected.to allow_value(nil).for(:required_instance_ci_template) }
      it { is_expected.not_to allow_value("").for(:required_instance_ci_template) }
      it { is_expected.not_to allow_value("  ").for(:required_instance_ci_template) }
      it { is_expected.to allow_value("template_name").for(:required_instance_ci_template) }
    end

    describe 'max_personal_access_token', feature_category: :user_management do
      context 'when extended lifetime is not selected' do
        before do
          stub_feature_flags(buffered_token_expiration_limit: false)
        end

        it 'validates max_personal_access_token_lifetime' do
          is_expected.to validate_numericality_of(:max_personal_access_token_lifetime)
            .only_integer.is_greater_than(0).is_less_than_or_equal_to(365).allow_nil
        end
      end

      context 'when extended lifetime is selected' do
        it 'validates max_personal_access_token_lifetime' do
          is_expected.to validate_numericality_of(:max_personal_access_token_lifetime)
            .only_integer.is_greater_than(0).is_less_than_or_equal_to(400).allow_nil
        end
      end
    end

    describe 'new_user_signups', feature_category: :onboarding do
      context 'when seat_control is user cap' do
        before do
          setting.update!(seat_control: described_class::SEAT_CONTROL_USER_CAP, new_user_signups_cap: 1)
        end

        it 'must be an integer' do
          setting.new_user_signups_cap = 1.5

          expect(setting).to be_invalid
          expect(setting.errors[:new_user_signups_cap]).to include('must be an integer')
        end

        it 'must be greater than 0' do
          setting.new_user_signups_cap = 0

          expect(setting).to be_invalid
          expect(setting.errors[:new_user_signups_cap]).to include('must be greater than 0')
        end

        it 'must not be empty' do
          setting.new_user_signups_cap = ""

          expect(setting).to be_invalid
          expect(setting.errors[:new_user_signups_cap]).to include('is not a number')
        end
      end

      context 'when seat_control is off' do
        before do
          setting.update!(seat_control: described_class::SEAT_CONTROL_OFF)
        end

        it 'can be nil' do
          setting.new_user_signups_cap = nil

          expect(setting).to be_valid
        end

        it 'can be an empty string' do
          setting.new_user_signups_cap = ""

          expect(setting).to be_valid
        end

        it 'must not be a number' do
          setting.new_user_signups_cap = 1

          expect(setting).to be_invalid
          expect(setting.errors[:new_user_signups_cap]).to include('must be blank')
        end
      end

      context 'when seat_control is block overages' do
        before do
          setting.update!(seat_control: described_class::SEAT_CONTROL_BLOCK_OVERAGES)
        end

        it 'can be nil' do
          setting.new_user_signups_cap = nil

          expect(setting).to be_valid
        end

        it 'can be an empty string' do
          setting.new_user_signups_cap = ""

          expect(setting).to be_valid
        end

        it 'must not be a number' do
          setting.new_user_signups_cap = 1

          expect(setting).to be_invalid
          expect(setting.errors[:new_user_signups_cap]).to include('must be blank')
        end
      end
    end

    describe 'user_seat_management', feature_category: :seat_cost_management do
      context 'for seat_control' do
        it 'allows update to user cap' do
          expect { setting.update!(seat_control: described_class::SEAT_CONTROL_USER_CAP, new_user_signups_cap: 1) }
            .to change { setting.seat_control }
              .from(described_class::SEAT_CONTROL_OFF).to(described_class::SEAT_CONTROL_USER_CAP)
        end

        it 'allows update to off' do
          setting.update!(seat_control: described_class::SEAT_CONTROL_USER_CAP, new_user_signups_cap: 1)

          expect { setting.update!(seat_control: described_class::SEAT_CONTROL_OFF, new_user_signups_cap: nil) }
            .to change { setting.seat_control }
              .from(described_class::SEAT_CONTROL_USER_CAP).to(described_class::SEAT_CONTROL_OFF)
        end

        it 'does not allow update to value > 2' do
          expect { setting.update!(seat_control: 3) }.to raise_error(
            ActiveRecord::RecordInvalid, "Validation failed: User seat management must be a valid json schema"
          )
        end

        it 'does not allow update to value < 0' do
          expect { setting.update!(seat_control: -1) }.to raise_error(
            ActiveRecord::RecordInvalid, "Validation failed: User seat management must be a valid json schema"
          )
        end
      end
    end

    describe 'git_two_factor', feature_category: :system_access do
      it 'validates git_two_factor_session_expiry' do
        is_expected.to validate_numericality_of(:git_two_factor_session_expiry)
          .only_integer.is_greater_than_or_equal_to(1).is_less_than_or_equal_to(10080)
      end

      it { is_expected.not_to allow_value(nil).for(:git_two_factor_session_expiry) }

      # TODO: test feature flag
      context 'when extended lifetime is selected' do
        it 'validates max_ssh_key_lifetime' do
          is_expected.to validate_numericality_of(:max_ssh_key_lifetime)
            .is_greater_than(0).is_less_than_or_equal_to(400).allow_nil
        end
      end

      context 'when extended lifetime is not selected' do
        before do
          stub_feature_flags(buffered_token_expiration_limit: false)
        end

        it 'validates max_ssh_key_lifetime' do
          is_expected.to validate_numericality_of(:max_ssh_key_lifetime)
            .is_greater_than(0).is_less_than_or_equal_to(365).allow_nil
        end
      end
    end

    describe 'namespace_storage_forks_cost_factor' do
      it 'validates namespace_storage_forks_cost_factor' do
        is_expected.to validate_numericality_of(:namespace_storage_forks_cost_factor)
          .is_greater_than_or_equal_to(0)
          .is_less_than_or_equal_to(1)
      end
    end

    describe 'dashboard', feature_category: :observability do
      it { is_expected.to validate_numericality_of(:dashboard_limit).only_integer.is_greater_than_or_equal_to(0) }
    end

    describe 'when additional email text is enabled', feature_category: :user_profile do
      before do
        stub_licensed_features(email_additional_text: true)
      end

      it { is_expected.to allow_value("a" * setting.email_additional_text_character_limit).for(:email_additional_text) }

      it 'does not allow over text character limit' do
        is_expected.not_to allow_value("a" * (setting.email_additional_text_character_limit + 1))
          .for(:email_additional_text)
      end
    end

    describe 'when secret detection token revocation is enabled', feature_category: :secret_detection do
      before do
        stub_application_setting(secret_detection_token_revocation_enabled: true)
      end

      it { is_expected.to allow_value("http://test.com").for(:secret_detection_token_revocation_url) }
      it { is_expected.to allow_value("AKVD34#$%56").for(:secret_detection_token_revocation_token) }
      it { is_expected.to allow_value("http://test.com").for(:secret_detection_revocation_token_types_url) }
    end

    describe 'when validating duo_chat settings' do
      it 'allows valid duo_chat_expiration_column' do
        setting.duo_chat_expiration_column = 'last_updated_at'
        expect(setting).to be_valid
      end

      it 'disallows invalid duo_chat_expiration_column' do
        setting.duo_chat_expiration_column = 'invalid_column'
        expect(setting).not_to be_valid
        expect(setting.errors.where(:duo_chat_expiration_column, :inclusion).present?).to be(true)
      end

      it 'uses the default value from jsonb_accessor' do
        expect(setting.duo_chat_expiration_column).to eq('last_updated_at')
      end
    end

    describe '#duo_availability' do
      using RSpec::Parameterized::TableSyntax

      where(:duo_features_enabled, :lock_duo_features_enabled, :expectation) do
        true  | false | :default_on
        false | false | :default_off
        false | true | :never_on
      end

      with_them do
        before do
          setting.duo_features_enabled = duo_features_enabled
          setting.lock_duo_features_enabled = lock_duo_features_enabled
        end

        it 'returns the expected response' do
          expect(setting.duo_availability).to eq(expectation)
        end
      end
    end

    describe '#duo_availability=' do
      using RSpec::Parameterized::TableSyntax

      where(:duo_availability, :duo_features_enabled_expectation, :lock_duo_features_enabled_expectation) do
        "default_on"  | true  | false
        "default_off" | false | false
        "never_on" | false | true
      end

      with_them do
        before do
          setting.duo_availability = duo_availability
        end

        it 'returns the expected response' do
          expect(setting.duo_features_enabled).to be duo_features_enabled_expectation
          expect(setting.lock_duo_features_enabled).to be lock_duo_features_enabled_expectation
        end
      end

      context 'when value is "never_on"' do
        it 'disables instance level AI and beta features' do
          setting.duo_availability = "never_on"

          expect(setting.instance_level_ai_beta_features_enabled).to be false
        end
      end
    end

    describe '#duo_never_on?' do
      it 'returns true when duo_availability is "never_on"' do
        setting.duo_availability = "never_on"
        expect(setting.duo_never_on?).to be true
      end

      it 'returns false when duo_availability is "default_on"' do
        setting.duo_availability = "default_on"
        expect(setting.duo_never_on?).to be false
      end

      it 'returns false when duo_availability is "default_off"' do
        setting.duo_availability = "default_off"
        expect(setting.duo_never_on?).to be false
      end
    end

    describe '#enabled_expanded_logging' do
      it "updates ::Ai::Settings.instance.enabled_instance_verbose_ai_logs" do
        ::Ai::Setting.instance.update!(enabled_instance_verbose_ai_logs: false)

        expect { setting.enabled_expanded_logging = true }
          .to change { ::Ai::Setting.instance.enabled_instance_verbose_ai_logs }
          .from(false).to(true)
      end
    end

    context 'when validating geo_node_allowed_ips', feature_category: :geo_replication do
      where(:allowed_ips, :is_valid) do
        "192.1.1.1"                   | true
        "192.1.1.0/24"                | true
        "192.1.1.0/24, 192.1.20.23"   | true
        "192.1.1.0/24, 192.23.0.0/16" | true
        "192.1.1.0/34"                | false
        "192.1.1.257"                 | false
        "192.1.1.257, 192.1.1.1"      | false
        "300.1.1.0/34"                | false
      end

      with_them do
        specify do
          setting.update_column(:geo_node_allowed_ips, allowed_ips)

          expect(setting.reload.valid?).to eq(is_valid)
        end
      end
    end

    context 'when validating globally_allowed_ips', feature_category: :geo_replication do
      where(:allowed_ips, :is_valid) do
        "192.1.1.1"                   | true
        "192.1.1.0/24"                | true
        "192.1.1.0/24, 192.1.20.23"   | true
        "192.1.1.0/24, 192.23.0.0/16" | true
        "192.1.1.0/34"                | false
        "192.1.1.257"                 | false
        "192.1.1.257, 192.1.1.1"      | false
        "300.1.1.0/34"                | false
      end

      with_them do
        specify do
          setting.update_column(:globally_allowed_ips, allowed_ips)

          expect(setting.reload.valid?).to eq(is_valid)
        end
      end
    end

    context 'when validating elasticsearch_url', feature_category: :global_search do
      where(:elasticsearch_url, :is_valid) do
        "http://es.localdomain" | true
        "https://es.localdomain" | true
        "http://es.localdomain, https://es.localdomain " | true
        "http://10.0.0.1" | true
        "https://10.0.0.1" | true
        "http://10.0.0.1, https://10.0.0.1" | true
        "http://localhost" | true
        "http://127.0.0.1" | true

        "es.localdomain" | false
        "10.0.0.1" | false
        "http://es.localdomain, es.localdomain" | false
        "http://es.localdomain, 10.0.0.1" | false
        "this_isnt_a_url" | false
      end

      with_them do
        specify do
          setting.elasticsearch_url = elasticsearch_url

          expect(setting.valid?).to eq(is_valid)
        end
      end

      context 'when outbound requests are blocked except for allowlist' do
        let(:blocked_domain_url) { 'http://blocked-domain.com' }
        let(:allowed_domain_url) { 'http://allowed-domain.com' }
        let(:allow_list) { ['allowed-domain.com'] }

        before do
          stub_application_setting(outbound_local_requests_whitelist: allow_list)
          stub_application_setting(diagramsnet_enabled: false)
          stub_application_setting(update_runner_versions_enabled: false)
          stub_application_setting(help_page_documentation_base_url: '')
          stub_application_setting(deny_all_requests_except_allowed: true)
        end

        it 'fails validation when elasticsearch_url is not in the outbound local requests allowlist' do
          setting.elasticsearch_url = blocked_domain_url

          expect(setting).not_to be_valid
          expect(setting.errors[:elasticsearch_url]).to include('only supports valid HTTP(S) URLs.')
        end

        it 'passes validation when elasticsearch_url is in the outbound local requests allowlist' do
          setting.elasticsearch_url = allowed_domain_url

          expect(setting).to be_valid
        end

        it 'verifies that UrlBlocker.validate! is called with the correct allowlist parameter' do
          setting.elasticsearch_url = allowed_domain_url
          expect(Gitlab::HTTP_V2::UrlBlocker)
            .to receive(:validate!)
            .with(URI.parse(allowed_domain_url), anything)

          setting.validate
        end
      end
    end

    context 'for Sentry', feature_category: :observability do
      context 'when Sentry is enabled' do
        before do
          setting.sentry_enabled = true
        end

        it { is_expected.to allow_value(false).for(:sentry_enabled) }
        it { is_expected.not_to allow_value(nil).for(:sentry_enabled) }

        it { is_expected.to allow_value('http://example.com').for(:sentry_dsn) }
        it { is_expected.not_to allow_value("http://#{'a' * 255}.com").for(:sentry_dsn) }
        it { is_expected.not_to allow_value('example').for(:sentry_dsn) }
        it { is_expected.not_to allow_value(nil).for(:sentry_dsn) }

        it { is_expected.to allow_value('http://example.com').for(:sentry_clientside_dsn) }
        it { is_expected.to allow_value(nil).for(:sentry_clientside_dsn) }
        it { is_expected.not_to allow_value('example').for(:sentry_clientside_dsn) }
        it { is_expected.not_to allow_value("http://#{'a' * 255}.com").for(:sentry_clientside_dsn) }

        it { is_expected.to allow_value('production').for(:sentry_environment) }
        it { is_expected.not_to allow_value(nil).for(:sentry_environment) }
        it { is_expected.not_to allow_value('a' * 256).for(:sentry_environment) }
      end

      context 'when Sentry is disabled' do
        before do
          setting.sentry_enabled = false
        end

        it { is_expected.not_to allow_value(nil).for(:sentry_enabled) }
        it { is_expected.to allow_value(nil).for(:sentry_dsn) }
        it { is_expected.to allow_value(nil).for(:sentry_clientside_dsn) }
        it { is_expected.to allow_value(nil).for(:sentry_environment) }
      end
    end

    describe 'git abuse rate limit validations', feature_category: :insider_threat do
      it 'validates max_number_of_repository_downloads' do
        is_expected.to validate_numericality_of(:max_number_of_repository_downloads)
        .is_greater_than_or_equal_to(0).is_less_than_or_equal_to(10_000)
      end

      it 'validates max_number_of_repository_downloads_within_time_period' do
        is_expected.to validate_numericality_of(:max_number_of_repository_downloads_within_time_period)
          .is_greater_than_or_equal_to(0).is_less_than_or_equal_to(10.days.to_i)
      end

      describe 'git_rate_limit_users_allowlist' do
        let_it_be(:user) { create(:user) }

        it { is_expected.to allow_value([]).for(:git_rate_limit_users_allowlist) }
        it { is_expected.to allow_value([user.username]).for(:git_rate_limit_users_allowlist) }
        it { is_expected.not_to allow_value(nil).for(:git_rate_limit_users_allowlist) }
        it { is_expected.not_to allow_value(['unknown_user']).for(:git_rate_limit_users_allowlist) }

        context 'when maximum length is exceeded' do
          it 'is not valid' do
            setting.git_rate_limit_users_allowlist = Array.new(101) { |i| "user#{i}" }

            expect(setting).not_to be_valid
            expect(setting.errors[:git_rate_limit_users_allowlist]).to include("exceeds maximum length (100 usernames)")
          end
        end

        context 'when attr is not changed' do
          before do
            setting.git_rate_limit_users_allowlist = [non_existing_record_id]
            setting.save!(validate: false)
          end

          it { is_expected.to be_valid }
        end
      end

      describe 'git_rate_limit_users_alertlist' do
        let_it_be(:user) { create(:user) }

        it { is_expected.to allow_value([]).for(:git_rate_limit_users_alertlist) }
        it { is_expected.to allow_value([user.id]).for(:git_rate_limit_users_alertlist) }
        it { is_expected.to allow_value(nil).for(:git_rate_limit_users_alertlist) }
        it { is_expected.not_to allow_value([non_existing_record_id]).for(:git_rate_limit_users_alertlist) }

        context 'when maximum length is exceeded' do
          it 'is not valid' do
            setting.git_rate_limit_users_alertlist = Array.new(101)

            expect(setting).not_to be_valid
            expect(setting.errors[:git_rate_limit_users_alertlist]).to include('exceeds maximum length (100 user ids)')
          end
        end

        context 'when attr is not changed' do
          before do
            setting.git_rate_limit_users_alertlist = [non_existing_record_id]
            setting.save!(validate: false)
          end

          it { is_expected.to be_valid }
        end

        context 'when empty' do
          let!(:active_admin) { create(:admin) }
          let!(:inactive_admin) { create(:admin, :deactivated) }

          it 'returns the user ids of the active admins' do
            expect(setting.git_rate_limit_users_alertlist).to contain_exactly(active_admin.id)
          end
        end

        context 'when not empty' do
          let(:alerted_user_ids) { [1, 3, 2] }

          before do
            setting.update_attribute(:git_rate_limit_users_alertlist, alerted_user_ids)
          end

          it 'returns the ordered set of user ids' do
            expect(setting.git_rate_limit_users_alertlist).to eq([1, 2, 3])
          end
        end
      end

      describe 'unique_project_download_limit_enabled' do
        context 'when max_number_of_repository_downloads is 0' do
          before do
            setting.max_number_of_repository_downloads = 0
            setting.max_number_of_repository_downloads_within_time_period = 300
            setting.save!
          end

          it 'allows project to be indexed' do
            expect(setting.unique_project_download_limit_enabled?).to be(false)
          end
        end

        context 'when max_number_of_repository_downloads_within_time_period is 0' do
          before do
            setting.max_number_of_repository_downloads = 1
            setting.max_number_of_repository_downloads_within_time_period = 0
            setting.save!
          end

          it 'allows project to be indexed' do
            expect(setting.unique_project_download_limit_enabled?).to be(false)
          end
        end

        context 'when neither are 0' do
          before do
            setting.max_number_of_repository_downloads = 1
            setting.max_number_of_repository_downloads_within_time_period = 300
            setting.save!
          end

          it 'allows project to be indexed' do
            expect(setting.unique_project_download_limit_enabled?).to be(true)
          end
        end
      end
    end

    describe 'when validating product analytics settings', feature_category: :product_analytics do
      context 'when product analytics is enabled' do
        before do
          setting.product_analytics_enabled = true
        end

        it { is_expected.to allow_value(false, '').for(:product_analytics_enabled) }

        it { is_expected.to allow_value('https://cube.gitlab.com', 'https://localhost:4000').for(:cube_api_base_url) }
        it { is_expected.not_to allow_value('invalid.host').for(:cube_api_base_url) }
        it { is_expected.to validate_presence_of(:cube_api_base_url) }
        it { is_expected.to validate_length_of(:cube_api_base_url).is_at_most(512) }

        it { is_expected.to allow_value('420d0e1b73b2ad4acd21c92e533be327').for(:cube_api_key) }
        it { is_expected.to validate_presence_of(:cube_api_key) }
        it { is_expected.to validate_length_of(:cube_api_key).is_at_most(255) }

        it { is_expected.to allow_value('https://collector.gitlab.com', 'http://localhost:8000').for(:product_analytics_data_collector_host) }
        it { is_expected.not_to allow_value('invalid.host').for(:product_analytics_data_collector_host) }
        it { is_expected.to validate_presence_of(:product_analytics_data_collector_host) }
        it { is_expected.to validate_length_of(:product_analytics_data_collector_host).is_at_most(255) }

        it { is_expected.to allow_value('https://configurator.gitlab.com', 'http://localhost:8000').for(:product_analytics_configurator_connection_string) }
        it { is_expected.not_to allow_value("invalid.host").for(:product_analytics_configurator_connection_string) }
        it { is_expected.to validate_presence_of(:product_analytics_configurator_connection_string) }
        it { is_expected.to validate_length_of(:product_analytics_configurator_connection_string).is_at_most(512) }

        it { is_expected.to allow_value('https://cube.gitlab.com').for(:cube_api_base_url) }
        it { is_expected.to allow_value('https://localhost:4000').for(:cube_api_base_url) }
        it { is_expected.not_to allow_value(nil).for(:cube_api_base_url) }
        it { is_expected.not_to allow_value("").for(:cube_api_base_url) }

        it { is_expected.not_to allow_value(nil).for(:product_analytics_configurator_connection_string) }
        it { is_expected.not_to allow_value("").for(:product_analytics_configurator_connection_string) }
      end

      context 'when product analytics is disabled' do
        before do
          setting.product_analytics_enabled = false
        end

        it { is_expected.to allow_value(nil).for(:cube_api_base_url) }
        it { is_expected.to allow_value(nil).for(:cube_api_key) }
        it { is_expected.to allow_value(nil).for(:product_analytics_data_collector_host) }
        it { is_expected.to allow_value(nil).for(:product_analytics_configurator_connection_string) }
      end
    end

    describe 'package_metadata_purl_types', feature_category: :software_composition_analysis do
      it { is_expected.to allow_value(1).for(:package_metadata_purl_types) }
      it { is_expected.to allow_value(Enums::Sbom::PURL_TYPES.length).for(:package_metadata_purl_types) }
      it { is_expected.not_to allow_value(Enums::Sbom::PURL_TYPES.length + 1).for(:package_metadata_purl_types) }
      it { is_expected.not_to allow_value(0).for(:package_metadata_purl_types) }
    end

    describe 'import_sources', feature_category: :importers do
      before do
        stub_licensed_features(custom_project_templates: true)
      end

      it { is_expected.to allow_value(['gitlab_custom_project_template']).for(:import_sources) }
    end

    context "for unconfirmed user deletion", feature_category: :user_management do
      context 'when email confirmation is set to hard' do
        before do
          stub_application_setting_enum('email_confirmation_setting', 'hard')
        end

        it { is_expected.to validate_numericality_of(:unconfirmed_users_delete_after_days).is_greater_than(0) }
      end

      context 'when email confirmation is set to soft' do
        let(:allow_unconfirmed_access_for) { 3 }

        before do
          stub_application_setting_enum('email_confirmation_setting', 'soft')
          allow(Devise).to receive(:allow_unconfirmed_access_for).and_return(allow_unconfirmed_access_for.days)
        end

        it 'validates unconfirmed_users_delete_after_days' do
          is_expected.to validate_numericality_of(:unconfirmed_users_delete_after_days)
            .is_greater_than(allow_unconfirmed_access_for)
        end
      end

      context 'when email confirmation is is off' do
        before do
          stub_application_setting_enum('email_confirmation_setting', 'off')
        end

        it { is_expected.to allow_value(false).for(:delete_unconfirmed_users) }
        it { is_expected.not_to allow_value(true).for(:delete_unconfirmed_users) }
      end
    end

    describe 'instance_level_ai_beta_features_enabled', feature_category: :plan_provisioning do
      it { is_expected.to allow_values([true, false]).for(:instance_level_ai_beta_features_enabled) }
      it { is_expected.not_to allow_value(nil).for(:instance_level_ai_beta_features_enabled) }
    end

    describe 'integrations settings', feature_category: :integrations do
      it { is_expected.to allow_values(%w[jira jenkins beyond_identity]).for(:allowed_integrations) }
      it { is_expected.not_to allow_values(['unknown_integration']).for(:allowed_integrations) }

      context 'when allowed_integrations has not changed' do
        before do
          setting.allowed_integrations = ['unknown_integration']
          setting.save!(validate: false)
          setting.reset
        end

        it 'allows unknown integrations' do
          is_expected.to be_valid
          expect(setting.allowed_integrations).to eq(['unknown_integration'])
        end
      end

      context 'when application settings do not allow all integrations' do
        before do
          stub_application_setting(allow_all_integrations: false)
          stub_licensed_features(integrations_allow_list: true)
        end

        it 'allows setting a new allowed integration' do
          setting.allowed_integrations = ['asana']
          expect(setting).to be_valid
        end
      end
    end

    context 'for non-null integer attributes starting from 0' do
      where(:attribute) do
        %i[
          virtual_registries_endpoints_api_limit
        ]
      end

      with_them do
        it { is_expected.to validate_numericality_of(attribute).only_integer.is_greater_than_or_equal_to(0) }
        it { is_expected.not_to allow_value(nil).for(attribute) }
      end
    end

    describe 'zoekt_indexing_timeout' do
      where(:zoekt_indexing_timeout, :is_valid) do
        '1m'    | true
        '2h'    | true
        '30d'   | true
        '1.5h'  | false
        '0'     | false
        '00'    | false
        '30D'   | false
        '5x'    | false
        '5mm'   | false
        '5md'   | false
        '0m'    | false
        '01d'   | false
        '5'     | false
        'm'     | false
        '1m '   | false
        ' 1m'   | false
      end

      with_them do
        specify do
          setting.zoekt_indexing_timeout = zoekt_indexing_timeout

          expect(setting.valid?).to eq(is_valid)
        end
      end
    end

    describe 'zoekt_rollout_retry_interval' do
      where(:zoekt_rollout_retry_interval, :is_valid) do
        '1m'    | true
        '2h'    | true
        '30d'   | true
        '0'     | true
        '1.5h'  | false
        '00'    | false
        '30D'   | false
        '5x'    | false
        '5mm'   | false
        '5md'   | false
        '0m'    | false
        '01d'   | false
        '5'     | false
        'm'     | false
        '1m '   | false
        ' 1m'   | false
      end

      with_them do
        specify do
          setting.zoekt_rollout_retry_interval = zoekt_rollout_retry_interval

          expect(setting.valid?).to eq(is_valid)
        end
      end
    end
  end

  describe 'search curation settings after .create_from_defaults', feature_category: :global_search do
    it { expect(setting.search_max_shard_size_gb).to eq(1) }
    it { expect(setting.search_max_docs_denominator).to eq(100) }
    it { expect(setting.search_min_docs_before_rollover).to eq(50) }

    context 'in production environments' do
      before do
        stub_rails_env "production"
      end

      it { expect(setting.search_max_shard_size_gb).to eq(50) }
      it { expect(setting.search_max_docs_denominator).to eq(5_000_000) }
      it { expect(setting.search_min_docs_before_rollover).to eq(100_000) }
    end
  end

  describe '#allowed_integrations_raw=' do
    before do
      setting.allowed_integrations_raw = '["asana","jira"]'
    end

    it 'sets allowed_integrations' do
      expect(setting.allowed_integrations).to contain_exactly('asana', 'jira')
    end
  end

  describe '#seat_control_user_cap?' do
    context 'when seat_control is set to user cap' do
      before do
        setting.seat_control = described_class::SEAT_CONTROL_USER_CAP
      end

      it 'returns true' do
        expect(setting.seat_control_user_cap?).to be true
      end
    end

    context 'when seat_control is off' do
      before do
        setting.seat_control = described_class::SEAT_CONTROL_OFF
      end

      it 'returns false' do
        expect(setting.seat_control_user_cap?).to be false
      end
    end
  end

  describe '#should_check_namespace_plan?', feature_category: :groups_and_projects do
    before do
      stub_application_setting(check_namespace_plan: check_namespace_plan_column)
      allow(::Gitlab).to receive(:org_or_com?) { gl_com }

      # This stub was added in order to force a fallback to Gitlab.org_or_com?
      # call testing.
      # Gitlab.org_or_com? responds to `false` on test envs
      # and we want to make sure we're still testing
      # should_check_namespace_plan? method through the test-suite (see
      # https://gitlab.com/gitlab-org/gitlab-foss/merge_requests/18461#note_69322821).
      allow(Rails).to receive_message_chain(:env, :development?).and_return(false)
      allow(Rails).to receive_message_chain(:env, :test?).and_return(false)
      allow(Rails).to receive_message_chain(:env, :production?).and_return(false)
    end

    subject { setting.should_check_namespace_plan? }

    context 'when check_namespace_plan true AND on GitLab.com' do
      let(:check_namespace_plan_column) { true }
      let(:gl_com) { true }

      it 'returns true' do
        is_expected.to be true
      end
    end

    context 'when check_namespace_plan true AND NOT on GitLab.com' do
      let(:check_namespace_plan_column) { true }
      let(:gl_com) { false }

      it 'returns false' do
        is_expected.to be false
      end
    end

    context 'when check_namespace_plan false AND on GitLab.com' do
      let(:check_namespace_plan_column) { false }
      let(:gl_com) { true }

      it 'returns false' do
        is_expected.to be false
      end
    end
  end

  describe '#repository_size_limit column', feature_category: :source_code_management do
    it 'support values up to 8 exabytes' do
      setting.update_column(:repository_size_limit, 8.exabytes - 1)

      setting.reload

      expect(setting.repository_size_limit).to eql(8.exabytes - 1)
    end
  end

  describe 'elasticsearch licensing', feature_category: :global_search do
    before do
      setting.elasticsearch_search = true
      setting.elasticsearch_indexing = true
    end

    def expect_is_es_licensed
      expect(License).to receive(:feature_available?).with(:elastic_search).at_least(:once)
    end

    it 'disables elasticsearch when unlicensed' do
      expect_is_es_licensed.and_return(false)

      expect(setting.elasticsearch_indexing?).to be_falsy
      expect(setting.elasticsearch_indexing).to be_falsy
      expect(setting.elasticsearch_search?).to be_falsy
      expect(setting.elasticsearch_search).to be_falsy
    end

    it 'enables elasticsearch when licensed' do
      expect_is_es_licensed.and_return(true)

      expect(setting.elasticsearch_indexing?).to be_truthy
      expect(setting.elasticsearch_indexing).to be_truthy
      expect(setting.elasticsearch_search?).to be_truthy
      expect(setting.elasticsearch_search).to be_truthy
    end

    it 'enables elasticsearch through usage ping features' do
      stub_usage_ping_features(true)
      allow(License).to receive(:current).and_return(nil)

      expect(setting.elasticsearch_indexing?).to be_truthy
      expect(setting.elasticsearch_indexing).to be_truthy
      expect(setting.elasticsearch_search?).to be_truthy
      expect(setting.elasticsearch_search).to be_truthy
    end
  end

  describe '#elasticsearch_url', feature_category: :global_search do
    it 'presents a single URL as a one-element array' do
      setting.elasticsearch_url = 'http://example.com'

      expect(setting.elasticsearch_url).to match_array([URI.parse('http://example.com')])
    end

    it 'presents multiple URLs as a many-element array' do
      setting.elasticsearch_url = 'http://example.com,https://invalid.invalid:9200'

      expect(setting.elasticsearch_url).to match_array([URI.parse('http://example.com'), URI.parse('https://invalid.invalid:9200')])
    end

    it 'strips whitespace from around URLs' do
      setting.elasticsearch_url = ' http://example.com, https://invalid.invalid:9200 '

      expect(setting.elasticsearch_url).to match_array([URI.parse('http://example.com'), URI.parse('https://invalid.invalid:9200')])
    end

    it 'strips trailing slashes from URLs' do
      setting.elasticsearch_url = 'http://example.com/, https://example.com:9200/, https://example.com:9200/prefix//'

      expect(setting.elasticsearch_url).to match_array([
        URI.parse('http://example.com'),
        URI.parse('https://example.com:9200'),
        URI.parse('https://example.com:9200/prefix')
      ])
    end
  end

  describe '#elasticsearch_url_with_credentials', feature_category: :global_search do
    let(:elasticsearch_url) { "#{host1},#{host2}" }
    let(:host1) { 'http://example.com' }
    let(:host2) { 'https://example.org:9200' }
    let(:elasticsearch_username) { 'elastic' }
    let(:elasticsearch_password) { 'password' }

    before do
      setting.elasticsearch_url = elasticsearch_url
      setting.elasticsearch_username = elasticsearch_username
      setting.elasticsearch_password = elasticsearch_password
    end

    context 'when credentials are embedded in url' do
      let(:elasticsearch_url) { 'http://username:password@example.com,https://test:test@example.org:9200' }

      it 'ignores them and uses elasticsearch_username and elasticsearch_password settings' do
        expect(setting.elasticsearch_url_with_credentials).to match_array(
          [
            {
              scheme: 'http',
              user: elasticsearch_username,
              password: elasticsearch_password,
              host: 'example.com',
              path: '',
              port: 80
            },
            {
              scheme: 'https',
              user: elasticsearch_username,
              password: elasticsearch_password,
              host: 'example.org',
              path: '',
              port: 9200
            }
          ])
      end
    end

    context 'when credential settings are blank' do
      let(:elasticsearch_username) { nil }
      let(:elasticsearch_password) { nil }

      it 'does not return credential info' do
        expect(setting.elasticsearch_url_with_credentials).to match_array(
          [
            { scheme: 'http', host: 'example.com', path: '', port: 80 },
            { scheme: 'https', host: 'example.org', path: '', port: 9200 }
          ])
      end

      context 'and url contains credentials' do
        let(:elasticsearch_url) { 'http://username:password@example.com,https://test:test@example.org:9200' }

        it 'returns credentials from url' do
          expect(setting.elasticsearch_url_with_credentials).to match_array(
            [
              { scheme: 'http', user: 'username', password: 'password', host: 'example.com', path: '', port: 80 },
              { scheme: 'https', user: 'test', password: 'test', host: 'example.org', path: '', port: 9200 }
            ])
        end
      end

      context 'and url contains credentials with special characters' do
        let(:elasticsearch_url) { 'http://admin:p%40ssword@localhost:9200/' }

        it 'returns decoded credentials from url' do
          expect(setting.elasticsearch_url_with_credentials).to match_array(
            [
              { scheme: 'http', user: 'admin', password: 'p@ssword', host: 'localhost', path: '', port: 9200 }
            ])
        end
      end
    end

    context 'when credentials settings have special characters' do
      let(:elasticsearch_username) { 'foo/admin' }
      let(:elasticsearch_password) { 'b@r+baz!$' }

      it 'returns the correct values' do
        expect(setting.elasticsearch_url_with_credentials).to match_array(
          [
            {
              scheme: 'http',
              user: elasticsearch_username,
              password: elasticsearch_password,
              host: 'example.com',
              path: '',
              port: 80
            },
            {
              scheme: 'https',
              user: elasticsearch_username,
              password: elasticsearch_password,
              host: 'example.org',
              path: '',
              port: 9200
            }
          ])
      end
    end
  end

  describe '#elasticsearch_password', feature_category: :global_search do
    it 'does not modify password if it is unchanged in the form' do
      setting.elasticsearch_password = 'foo'
      setting.elasticsearch_password = ApplicationSetting::MASK_PASSWORD

      expect(setting.elasticsearch_password).to eq('foo')
    end
  end

  describe '#elasticsearch_config', feature_category: :global_search do
    it 'places all elasticsearch configuration values into a hash' do
      allow(Rails.env).to receive(:test?).and_return(false)

      setting.update!(
        elasticsearch_url: 'http://example.com:9200',
        elasticsearch_username: 'foo',
        elasticsearch_password: 'bar',
        elasticsearch_aws: false,
        elasticsearch_aws_region: 'test-region',
        elasticsearch_aws_access_key: 'test-access-key',
        elasticsearch_aws_secret_access_key: 'test-secret-access-key',
        elasticsearch_max_bulk_size_mb: 67,
        elasticsearch_max_bulk_concurrency: 8,
        elasticsearch_client_request_timeout: 30
      )

      expect(setting.elasticsearch_config).to eq(
        url: [Gitlab::Elastic::Helper.connection_settings(uri: URI.parse('http://foo:bar@example.com:9200'))],
        aws: false,
        aws_region: 'test-region',
        aws_access_key: 'test-access-key',
        aws_secret_access_key: 'test-secret-access-key',
        max_bulk_size_bytes: 67.megabytes,
        max_bulk_concurrency: 8,
        client_request_timeout: 30
      )

      setting.update!(
        elasticsearch_client_request_timeout: 0
      )

      expect(setting.elasticsearch_config).not_to include(:client_request_timeout)
    end

    context 'when in test environment' do
      it 'uses the ELASTIC_REQUEST_TIMEOUT value instead of the database default' do
        expect(setting.elasticsearch_config)
          .to include(client_request_timeout: described_class::ELASTIC_REQUEST_TIMEOUT)
      end
    end

    context 'when limiting namespaces and projects' do
      before do
        setting.update!(elasticsearch_indexing: true)
        setting.update!(elasticsearch_limit_indexing: true)
      end

      context 'on namespaces' do
        context 'with personal namespaces' do
          let(:namespaces) { create_list(:namespace, 2) }
          let!(:indexed_namespace) { create :elasticsearch_indexed_namespace, namespace: namespaces.last }

          it 'tells you if a namespace is allowed to be indexed' do
            expect(setting.elasticsearch_indexes_namespace?(namespaces.last)).to be_truthy
            expect(setting.elasticsearch_indexes_namespace?(namespaces.first)).to be_falsey
          end
        end

        context 'with groups' do
          let(:groups) { create_list(:group, 2) }
          let!(:indexed_namespace) { create(:elasticsearch_indexed_namespace, namespace: groups.last) }
          let!(:child_group) { create(:group, parent: groups.first) }
          let!(:child_group_indexed_through_parent) { create(:group, parent: groups.last) }

          specify do
            create(:elasticsearch_indexed_namespace, namespace: child_group)

            expect(setting.elasticsearch_limited_namespaces).to match_array(
              [groups.last, child_group, child_group_indexed_through_parent])
            expect(setting.elasticsearch_limited_namespaces(true)).to match_array(
              [groups.last, child_group])
          end
        end

        describe '#elasticsearch_indexes_project?' do
          shared_examples 'whether the project is indexed' do
            context 'when project is in a subgroup' do
              let(:root_group) { create(:group) }
              let(:subgroup) { create(:group, parent: root_group) }
              let(:project) { create(:project, group: subgroup) }

              before do
                create(:elasticsearch_indexed_namespace, namespace: root_group)
              end

              it 'allows project to be indexed' do
                expect(setting.elasticsearch_indexes_project?(project)).to be(true)
              end
            end

            context 'when project is in a namespace' do
              let(:namespace) { create(:namespace) }
              let(:project) { create(:project, namespace: namespace) }

              before do
                create(:elasticsearch_indexed_namespace, namespace: namespace)
              end

              it 'allows project to be indexed' do
                expect(setting.elasticsearch_indexes_project?(project)).to be(true)
              end
            end
          end

          it_behaves_like 'whether the project is indexed'
        end
      end

      context 'on projects' do
        let(:projects) { create_list(:project, 2) }
        let!(:indexed_project) { create :elasticsearch_indexed_project, project: projects.last }

        it 'tells you if a project is allowed to be indexed' do
          expect(setting.elasticsearch_indexes_project?(projects.last)).to be(true)
          expect(setting.elasticsearch_indexes_project?(projects.first)).to be(false)
        end

        it 'returns projects that are allowed to be indexed' do
          project_indexed_through_namespace = create(:project)
          create :elasticsearch_indexed_namespace, namespace: project_indexed_through_namespace.namespace

          expect(setting.elasticsearch_limited_projects).to match_array(
            [projects.last, project_indexed_through_namespace])
        end

        it 'uses the ElasticsearchEnabledCache cache' do
          expect(::Gitlab::Elastic::ElasticsearchEnabledCache).to receive(:fetch).and_return(true)

          expect(setting.elasticsearch_indexes_project?(projects.first)).to be(true)
        end
      end
    end
  end

  describe '#invalidate_elasticsearch_indexes_cache', feature_category: :global_search do
    it 'deletes the ElasticsearchEnabledCache for projects and namespaces' do
      expect(::Gitlab::Elastic::ElasticsearchEnabledCache).to receive(:delete).with(:project)
      expect(::Gitlab::Elastic::ElasticsearchEnabledCache).to receive(:delete).with(:namespace)

      setting.invalidate_elasticsearch_indexes_cache!
    end
  end

  describe '#invalidate_elasticsearch_indexes_cache_for_project!', feature_category: :global_search do
    it 'deletes the ElasticsearchEnabledCache for a single project' do
      project_id = 1
      expect(::Gitlab::Elastic::ElasticsearchEnabledCache).to receive(:delete_record).with(:project, project_id)

      setting.invalidate_elasticsearch_indexes_cache_for_project!(project_id)
    end
  end

  describe '#invalidate_elasticsearch_indexes_cache_for_namespace!', feature_category: :global_search do
    it 'deletes the ElasticsearchEnabledCache for a namespace' do
      namespace_id = 1
      expect(::Gitlab::Elastic::ElasticsearchEnabledCache).to receive(:delete_record).with(:namespace, namespace_id)

      setting.invalidate_elasticsearch_indexes_cache_for_namespace!(namespace_id)
    end
  end

  describe '#search_using_elasticsearch?', feature_category: :global_search do
    # Constructs a truth table to run the specs against
    where(
      indexing: [true, false],
      searching: [true, false],
      limiting: [true, false],
      global_search_limited_indexing_enabled:
      [true, false]
    )

    with_them do
      let_it_be(:included_project_container) { create(:elasticsearch_indexed_project) }
      let_it_be(:included_namespace_container) { create(:elasticsearch_indexed_namespace) }

      let_it_be(:included_project) { included_project_container.project }
      let_it_be(:included_namespace) { included_namespace_container.namespace }

      let_it_be(:excluded_project) { create(:project) }
      let_it_be(:excluded_namespace) { create(:namespace) }

      let(:only_when_enabled_globally) { indexing && searching && !limiting }

      subject { setting.search_using_elasticsearch?(scope: scope) }

      before do
        setting.update!(
          elasticsearch_indexing: indexing,
          elasticsearch_search: searching,
          elasticsearch_limit_indexing: limiting
        )

        stub_ee_application_setting(global_search_limited_indexing_enabled: global_search_limited_indexing_enabled)
      end

      context 'for global scope' do
        let(:scope) { nil }

        it { is_expected.to eq(indexing && searching && (!limiting || global_search_limited_indexing_enabled)) }
      end

      context 'for namespace (in scope)' do
        let(:scope) { included_namespace }

        it { is_expected.to eq(indexing && searching) }
      end

      context 'for namespace (not in scope)' do
        let(:scope) { excluded_namespace }

        it { is_expected.to eq(only_when_enabled_globally) }
      end

      context 'for project (in scope)' do
        let(:scope) { included_project }

        it { is_expected.to eq(indexing && searching) }
      end

      context 'for project (not in scope)' do
        let(:scope) { excluded_project }

        it { is_expected.to eq(only_when_enabled_globally) }
      end
    end
  end

  describe 'custom project templates', feature_category: :groups_and_projects do
    let(:group) { create(:group) }
    let(:projects) { create_list(:project, 3, namespace: group) }

    before do
      setting.update_column(:custom_project_templates_group_id, group.id)

      setting.reload
    end

    context 'when custom_project_templates feature is enabled' do
      before do
        stub_licensed_features(custom_project_templates: true)
      end

      describe '#custom_project_templates_enabled?' do
        it 'returns true' do
          expect(setting.custom_project_templates_enabled?).to be_truthy
        end
      end

      describe '#custom_project_template_id' do
        it 'returns group id' do
          expect(setting.custom_project_templates_group_id).to eq group.id
        end
      end

      describe '#available_custom_project_templates' do
        it 'returns group projects' do
          expect(setting.available_custom_project_templates).to match_array(projects)
        end

        it 'returns an empty array if group is not set' do
          allow(setting).to receive(:custom_project_template_id).and_return(nil)

          expect(setting.available_custom_project_templates).to eq []
        end
      end
    end

    context 'when custom_project_templates feature is disabled' do
      before do
        stub_licensed_features(custom_project_templates: false)
      end

      describe '#custom_project_templates_enabled?' do
        it 'returns false' do
          expect(setting.custom_project_templates_enabled?).to be false
        end
      end

      describe '#custom_project_template_id' do
        it 'returns nil' do
          expect(setting.custom_project_templates_group_id).to be_nil
        end
      end

      describe '#available_custom_project_templates' do
        it 'returns an empty relation' do
          expect(setting.available_custom_project_templates).to be_empty
        end
      end
    end
  end

  describe '#instance_review_permitted?', feature_category: :onboarding do
    subject(:instance_review_permitted?) { setting.instance_review_permitted? }

    context 'for instances with a valid license' do
      before do
        license = create(:license, plan: ::License::PREMIUM_PLAN)
        allow(License).to receive(:current).and_return(license)
      end

      it 'is not permitted' do
        expect(instance_review_permitted?).to be_falsey
      end
    end

    context 'for instances without a valid license' do
      before do
        allow(License).to receive(:current).and_return(nil)
        allow(Rails.cache).to receive(:fetch).and_return(
          ::ApplicationSetting::INSTANCE_REVIEW_MIN_USERS + users_over_minimum
        )
      end

      where(users_over_minimum: [-1, 0, 1])

      with_them do
        it { is_expected.to be(users_over_minimum >= 0) }
      end
    end
  end

  describe '#max_personal_access_token_lifetime_from_now', feature_category: :user_management do
    subject(:max_personal_access_token_lifetime_from_now) { setting.max_personal_access_token_lifetime_from_now }

    let(:days_from_now) { nil }

    before do
      stub_application_setting(max_personal_access_token_lifetime: days_from_now)
    end

    context 'when max_personal_access_token_lifetime is defined' do
      let(:days_from_now) { 30 }

      it 'is a date time' do
        expect(max_personal_access_token_lifetime_from_now).to be_a Date
      end

      it 'is in the future' do
        expect(max_personal_access_token_lifetime_from_now).to be > Date.current
      end

      it 'is in days_from_now' do
        expect((max_personal_access_token_lifetime_from_now.to_date - Date.current).to_i).to eq days_from_now
      end
    end

    context 'when max_personal_access_token_lifetime is nil' do
      it 'is nil' do
        expect(max_personal_access_token_lifetime_from_now).to be_nil
      end
    end
  end

  describe 'updates to max_personal_access_token_lifetime', feature_category: :user_management do
    context 'without personal_access_token_expiration_policy licensed' do
      before do
        stub_licensed_features(personal_access_token_expiration_policy: false)
      end

      it "doesn't call the update lifetime service" do
        expect(::PersonalAccessTokens::Instance::UpdateLifetimeService).not_to receive(:new)

        setting.save!
      end
    end

    context 'with personal_access_token_expiration_policy licensed' do
      before do
        setting.max_personal_access_token_lifetime = 30
        stub_licensed_features(personal_access_token_expiration_policy: true)
      end

      it 'executes the update lifetime service' do
        expect_next_instance_of(::PersonalAccessTokens::Instance::UpdateLifetimeService) do |service|
          expect(service).to receive(:execute)
        end

        setting.save!
      end
    end
  end

  describe '#compliance_frameworks', feature_category: :compliance_management do
    it 'sorts the list' do
      setting.compliance_frameworks = [5, 4, 1, 3, 2]

      expect(setting.compliance_frameworks).to eq([1, 2, 3, 4, 5])
    end

    it 'removes duplicates' do
      setting.compliance_frameworks = [1, 2, 2, 3, 3, 3]

      expect(setting.compliance_frameworks).to eq([1, 2, 3])
    end

    it 'sets empty values' do
      setting.compliance_frameworks = [""]

      expect(setting.compliance_frameworks).to eq([])
    end
  end

  describe 'maintenance mode setting', feature_category: :geo_replication do
    it 'defaults to false' do
      expect(setting.maintenance_mode).to be false
    end
  end

  describe "#max_ssh_key_lifetime_from_now", :freeze_time, feature_category: :system_access do
    subject(:max_ssh_key_lifetime_from_now) { setting.max_ssh_key_lifetime_from_now }

    let(:days_from_now) { nil }

    before do
      stub_application_setting(max_ssh_key_lifetime: days_from_now)
    end

    context 'when max_ssh_key_lifetime is defined' do
      let(:days_from_now) { 30 }

      it 'is a date time' do
        is_expected.to be_a Time
      end

      it 'is in the future' do
        is_expected.to be_future
      end

      it 'is in days_from_now' do
        expect(max_ssh_key_lifetime_from_now.to_date - Time.zone.today).to eq days_from_now
      end
    end

    context 'when max_ssh_key_lifetime is nil' do
      it 'is nil' do
        is_expected.to be_nil
      end
    end
  end

  describe '#personal_access_tokens_disabled?', feature_category: :user_management do
    subject { setting.personal_access_tokens_disabled? }

    context 'when disable_personal_access_tokens feature is available' do
      before do
        stub_licensed_features(disable_personal_access_tokens: true)
      end

      context 'when personal access tokens are disabled' do
        before do
          stub_application_setting(disable_personal_access_tokens: true)
        end

        it { is_expected.to be true }
      end

      context 'when personal access tokens are not disabled' do
        it { is_expected.to be false }
      end
    end
  end

  describe '#disable_feed_token', feature_category: :user_management do
    subject { setting.disable_feed_token }

    before do
      setting.update!(disable_feed_token: false)
    end

    context 'when personal access tokens are disabled' do
      before do
        stub_licensed_features(disable_personal_access_tokens: true)
        stub_application_setting(disable_personal_access_tokens: true)
      end

      it { is_expected.to be true }
    end

    context 'when personal access tokens are enabled' do
      it { is_expected.to be false }
    end
  end

  describe 'ClickHouseForAnalyticsEnabledEvent publishing' do
    it 'publishes the event when use_clickhouse_for_analytics is changed to enabled', :freeze_time do
      setting.update!(use_clickhouse_for_analytics: false)
      expect do
        setting.update!(use_clickhouse_for_analytics: true)
      end.to publish_event(::Analytics::ClickHouseForAnalyticsEnabledEvent)
                     .with(enabled_at: Time.current.iso8601)
    end

    it 'does not publish the event when use_clickhouse_for_analytics is changed to disabled' do
      setting.update!(use_clickhouse_for_analytics: true)
      expect do
        setting.update!(use_clickhouse_for_analytics: false)
      end.not_to publish_event(::Analytics::ClickHouseForAnalyticsEnabledEvent)
    end

    it 'does not publish the event when use_clickhouse_for_analytics is not changed' do
      setting.update!(use_clickhouse_for_analytics: true)
      expect do
        setting.update!(use_clickhouse_for_analytics: true)
      end.not_to publish_event(::Analytics::ClickHouseForAnalyticsEnabledEvent)
    end
  end
end
