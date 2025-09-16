# frozen_string_literal: true

module EE
  module ApplicationSettingsHelper
    extend ::Gitlab::Utils::Override
    include ::GitlabSubscriptions::MemberManagement::PromotionManagementUtils

    override :visible_attributes
    def visible_attributes
      super + [
        :allow_all_integrations,
        :allowed_integrations,
        :allow_group_owners_to_manage_ldap,
        :automatic_purchased_storage_allocation,
        :check_namespace_plan,
        :duo_chat_expiration_column,
        :duo_chat_expiration_days,
        :elasticsearch_aws_access_key,
        :elasticsearch_aws_region,
        :elasticsearch_aws_role_arn,
        :elasticsearch_aws_secret_access_key,
        :elasticsearch_aws,
        :elasticsearch_client_request_timeout,
        :elasticsearch_indexed_field_length_limit,
        :elasticsearch_indexed_file_size_limit_kb,
        :elasticsearch_indexing,
        :elasticsearch_requeue_workers,
        :elasticsearch_limit_indexing,
        :elasticsearch_worker_number_of_shards,
        :elasticsearch_max_bulk_concurrency,
        :elasticsearch_max_bulk_size_mb,
        :elasticsearch_max_code_indexing_concurrency,
        :elasticsearch_namespace_ids,
        :elasticsearch_pause_indexing,
        :elasticsearch_project_ids,
        :elasticsearch_retry_on_failure,
        :elasticsearch_replicas,
        :elasticsearch_search,
        :elasticsearch_shards,
        :elasticsearch_url,
        :elasticsearch_username,
        :elasticsearch_password,
        :elasticsearch_limit_indexing,
        :elasticsearch_namespace_ids,
        :elasticsearch_project_ids,
        :elasticsearch_client_request_timeout,
        :elasticsearch_analyzers_smartcn_enabled,
        :elasticsearch_analyzers_smartcn_search,
        :elasticsearch_analyzers_kuromoji_enabled,
        :elasticsearch_analyzers_kuromoji_search,
        :enforce_namespace_storage_limit,
        :geo_node_allowed_ips,
        :geo_status_timeout,
        :instance_level_ai_beta_features_enabled,
        :model_prompt_cache_enabled,
        :lock_memberships_to_ldap,
        :lock_memberships_to_saml,
        :max_personal_access_token_lifetime,
        :max_ssh_key_lifetime,
        :receptive_cluster_agents_enabled,
        :repository_size_limit,
        :search_max_shard_size_gb,
        :search_max_docs_denominator,
        :search_min_docs_before_rollover,
        :secret_detection_token_revocation_enabled,
        :secret_detection_token_revocation_url,
        :secret_detection_token_revocation_token,
        :secret_detection_revocation_token_types_url,
        :shared_runners_minutes,
        :throttle_incident_management_notification_enabled,
        :throttle_incident_management_notification_per_period,
        :throttle_incident_management_notification_period_in_seconds,
        :package_metadata_purl_types,
        :product_analytics_enabled,
        :product_analytics_data_collector_host,
        :product_analytics_configurator_connection_string,
        :cube_api_base_url,
        :cube_api_key,
        :security_policy_global_group_approvers_enabled,
        :security_approval_policies_limit,
        :duo_features_enabled,
        :lock_duo_features_enabled,
        :duo_availability,
        :enabled_expanded_logging,
        # Add all Zoekt settings automatically
        *::Search::Zoekt::Settings.all_settings.keys,
        :duo_workflow_oauth_application_id,
        :scan_execution_policies_action_limit,
        :scan_execution_policies_schedule_limit,
        :pipeline_execution_policies_per_configuration_limit,
        :secret_detection_service_auth_token,
        :secret_detection_service_url,
        :fetch_observability_alerts_from_cloud,
        :global_search_code_enabled,
        :global_search_commits_enabled,
        :global_search_wiki_enabled,
        :global_search_epics_enabled,
        :global_search_limited_indexing_enabled,
        :elastic_migration_worker_enabled,
        :enforce_pipl_compliance
      ].tap do |settings|
        settings.concat(identity_verification_attributes)
        settings.concat(enable_promotion_management_attributes)
      end
    end

    def elasticsearch_objects_options(objects)
      objects.map { |g| { id: g.id, text: g.full_path } }
    end

    # The admin UI cannot handle so many namespaces so we just hide it. We
    # assume people doing this are using automation anyway.
    def elasticsearch_too_many_namespaces?
      ElasticsearchIndexedNamespace.count > 50
    end

    # The admin UI cannot handle so many projects so we just hide it. We
    # assume people doing this are using automation anyway.
    def elasticsearch_too_many_projects?
      ElasticsearchIndexedProject.count > 50
    end

    def elasticsearch_namespace_ids
      ElasticsearchIndexedNamespace.target_ids.join(',')
    end

    def elasticsearch_project_ids
      ElasticsearchIndexedProject.target_ids.join(',')
    end

    def self.repository_mirror_attributes
      [
        :mirror_max_capacity,
        :mirror_max_delay,
        :mirror_capacity_threshold
      ]
    end

    def self.possible_licensed_attributes
      repository_mirror_attributes +
        merge_request_appovers_rules_attributes +
        password_complexity_attributes +
        git_abuse_rate_limit_attributes +
        delete_unconfirmed_users_attributes +
        %i[
          email_additional_text
          file_template_project_id
          git_two_factor_session_expiry
          group_owners_can_manage_default_branch_protection
          default_project_deletion_protection
          disable_personal_access_tokens
          updating_name_disabled_for_users
          maven_package_requests_forwarding
          npm_package_requests_forwarding
          secret_push_protection_available
          pypi_package_requests_forwarding
          maintenance_mode
          maintenance_mode_message
          globally_allowed_ips
          service_access_tokens_expiration_enforced
          disabled_direct_code_suggestions
          allow_top_level_group_owners_to_create_service_accounts
          secret_detection_service_auth_token
          secret_detection_service_url
          virtual_registries_endpoints_api_limit
          disable_invite_members
        ]
    end

    def self.merge_request_appovers_rules_attributes
      %i[
        disable_overriding_approvers_per_merge_request
        prevent_merge_requests_author_approval
        prevent_merge_requests_committers_approval
      ]
    end

    def self.password_complexity_attributes
      %i[
        password_number_required
        password_symbol_required
        password_uppercase_required
        password_lowercase_required
      ]
    end

    def self.git_abuse_rate_limit_attributes
      %i[
        max_number_of_repository_downloads
        max_number_of_repository_downloads_within_time_period
        git_rate_limit_users_allowlist
        git_rate_limit_users_alertlist
        auto_ban_user_on_excessive_projects_download
      ]
    end

    def self.delete_unconfirmed_users_attributes
      %i[
        delete_unconfirmed_users
        unconfirmed_users_delete_after_days
      ]
    end

    override :registration_features_can_be_prompted?
    def registration_features_can_be_prompted?
      !::Gitlab::CurrentSettings.usage_ping_enabled? && !License.current.present?
    end

    override :signup_form_data
    def signup_form_data
      form_data = super

      if ::License.feature_available?(:password_complexity)
        form_data.merge!({
          password_uppercase_required: @application_setting[:password_uppercase_required].to_s,
          password_lowercase_required: @application_setting[:password_lowercase_required].to_s,
          password_number_required: @application_setting[:password_number_required].to_s,
          password_symbol_required: @application_setting[:password_symbol_required].to_s
        })
      end

      licensed_users_count = ::License.current&.seats
      form_data[:licensed_user_count] = licensed_users_count ? licensed_users_count.to_s : ''

      promotion_management_available = member_promotion_management_feature_available?
      form_data[:promotion_management_available] = promotion_management_available.to_s
      if promotion_management_available
        form_data[:enable_member_promotion_management] = @application_setting[:enable_member_promotion_management].to_s
        form_data[:can_disable_member_promotion_management] =
          ::GitlabSubscriptions::MemberManagement::SelfManaged::MaxAccessLevelMemberApprovalsFinder.new(current_user)
            .execute.empty?.to_s
        form_data[:role_promotion_requests_path] = admin_role_promotion_requests_path
      end

      seat_control = License.feature_available?(:seat_control) ? @application_setting[:seat_control] : ''
      form_data[:seat_control] = seat_control.to_s

      form_data
    end

    def git_abuse_rate_limit_data
      limit = @application_setting[:max_number_of_repository_downloads].to_i
      interval = @application_setting[:max_number_of_repository_downloads_within_time_period].to_i
      allowlist = @application_setting[:git_rate_limit_users_allowlist].to_a
      alertlist = @application_setting.git_rate_limit_users_alertlist
      auto_ban_users = @application_setting[:auto_ban_user_on_excessive_projects_download].to_s

      {
        max_number_of_repository_downloads: limit,
        max_number_of_repository_downloads_within_time_period: interval,
        git_rate_limit_users_allowlist: allowlist,
        git_rate_limit_users_alertlist: alertlist,
        auto_ban_user_on_excessive_projects_download: auto_ban_users
      }
    end

    def sync_purl_types_checkboxes(form)
      ::Enums::Sbom.purl_types.keys.map do |name|
        checked = @application_setting.package_metadata_purl_types_names.include?(name)
        numeric = ::Enums::Sbom.purl_types[name]

        form.gitlab_ui_checkbox_component(
          :package_metadata_purl_types,
          name,
          checkbox_options: { checked: checked, multiple: true, autocomplete: 'off',
                              data: { testid: "#{name}-checkbox" } },
          checked_value: numeric,
          unchecked_value: nil
        )
      end
    end

    override :global_search_settings_checkboxes
    def global_search_settings_checkboxes(form)
      return super unless License.feature_available?(:elastic_search)

      super + [
        form.gitlab_ui_checkbox_component(
          :global_search_code_enabled,
          _("Show code in global search results"),
          checkbox_options: { checked: @application_setting.global_search_code_enabled, multiple: false }
        ),
        form.gitlab_ui_checkbox_component(
          :global_search_commits_enabled,
          _("Show commits in global search results"),
          checkbox_options: { checked: @application_setting.global_search_commits_enabled, multiple: false }
        ),
        form.gitlab_ui_checkbox_component(
          :global_search_epics_enabled,
          _("Show epics in global search results"),
          checkbox_options: { checked: @application_setting.global_search_epics_enabled, multiple: false }
        ),
        form.gitlab_ui_checkbox_component(
          :global_search_wiki_enabled,
          _("Show wikis in global search results"),
          checkbox_options: { checked: @application_setting.global_search_wiki_enabled, multiple: false }
        )
      ]
    end

    override :vscode_extension_marketplace_settings_description
    def vscode_extension_marketplace_settings_description
      if License.feature_available?(:remote_development)
        _('Enable VS Code Extension Marketplace and configure the extensions registry for Web IDE and Workspaces.')
      else
        super
      end
    end

    def zoekt_settings_checkboxes(form)
      ::Search::Zoekt::Settings.boolean_settings.map do |setting_name, config|
        form.gitlab_ui_checkbox_component(
          setting_name,
          instance_exec(&config[:label]),
          checkbox_options: {
            checked: @application_setting.public_send(setting_name), # rubocop:disable GitlabSecurity/PublicSend -- we control `setting_name` in source code
            multiple: false
          }
        )
      end
    end

    def zoekt_settings_inputs(form)
      ::Search::Zoekt::Settings.input_settings.flat_map do |setting_name, config|
        options = {
          value: @application_setting.public_send(setting_name), # rubocop:disable GitlabSecurity/PublicSend -- we control `setting_name` in source code
          class: 'form-control gl-form-input'
        }.merge(config[:input_options] || {})
        input_field = case config[:input_type]
                      when :number_field
                        form.number_field(setting_name, options)
                      when :text_field
                        form.text_field(setting_name, options)
                      else
                        raise ArgumentError, "Unknown input_type: #{config[:input_type]}"
                      end

        [
          form.label(setting_name, instance_exec(&config[:label]), class: 'label-bold'),
          input_field
        ]
      end
    end

    def compliance_security_policy_group_id
      Security::PolicySetting.for_organization(::Organizations::Organization.default_organization).csp_namespace_id
    end

    private

    def identity_verification_attributes
      return [] unless ::Gitlab::Saas.feature_available?(:identity_verification)

      %i[
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
        telesign_api_key
        telesign_customer_xid
      ]
    end

    def enable_promotion_management_attributes
      return [] if ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)

      %i[enable_member_promotion_management]
    end
  end
end
