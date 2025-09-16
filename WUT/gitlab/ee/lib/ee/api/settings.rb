# frozen_string_literal: true

module EE
  module API
    module Settings
      extend ActiveSupport::Concern

      prepended do
        helpers do
          extend ::Gitlab::Utils::Override

          # rubocop:disable Metrics/CyclomaticComplexity
          # rubocop:disable Metrics/PerceivedComplexity
          # rubocop:disable Metrics/AbcSize

          override :filter_attributes_using_license
          def filter_attributes_using_license(attrs)
            unless ::License.feature_available?(:repository_mirrors)
              attrs = attrs.except(*::EE::ApplicationSettingsHelper.repository_mirror_attributes)
            end

            unless ::License.feature_available?(:email_additional_text)
              attrs = attrs.except(:email_additional_text)
            end

            unless ::License.feature_available?(:custom_file_templates)
              attrs = attrs.except(:file_template_project_id)
            end

            unless ::License.feature_available?(:default_project_deletion_protection)
              attrs = attrs.except(:default_project_deletion_protection)
            end

            unless License.feature_available?(:disable_name_update_for_users)
              attrs = attrs.except(:updating_name_disabled_for_users)
            end

            unless License.feature_available?(:admin_merge_request_approvers_rules)
              attrs = attrs.except(*EE::ApplicationSettingsHelper.merge_request_appovers_rules_attributes)
            end

            unless License.feature_available?(:package_forwarding)
              attrs = attrs.except(
                :npm_package_requests_forwarding,
                :pypi_package_requests_forwarding,
                :maven_package_requests_forwarding
              )
            end

            unless License.feature_available?(:packages_virtual_registry)
              attrs = attrs.except(
                :virtual_registries_endpoints_api_limit
              )
            end

            unless ::License.feature_available?(:password_complexity)
              attrs = attrs.except(*EE::ApplicationSettingsHelper.password_complexity_attributes)
            end

            unless License.feature_available?(:default_branch_protection_restriction_in_groups)
              attrs = attrs.except(:group_owners_can_manage_default_branch_protection)
            end

            unless License.feature_available?(:git_two_factor_enforcement) && ::Feature.enabled?(:two_factor_for_cli)
              attrs = attrs.except(:git_two_factor_session_expiry)
            end

            unless RegistrationFeatures::MaintenanceMode.feature_available?
              attrs = attrs.except(:maintenance_mode, :maintenance_mode_message)
            end

            unless License.feature_available?(:git_abuse_rate_limit)
              attrs = attrs.except(*EE::ApplicationSettingsHelper.git_abuse_rate_limit_attributes)
            end

            unless License.feature_available?(:disable_personal_access_tokens)
              attrs = attrs.except(:disable_personal_access_tokens)
            end

            unless License.feature_available?(:delete_unconfirmed_users)
              attrs = attrs.except(:delete_unconfirmed_users_attributes)
            end

            unless License.feature_available?(:disable_private_profiles)
              attrs = attrs.except(:make_profile_private)
            end

            unless License.feature_available?(:service_accounts)
              attrs = attrs.except(:service_access_tokens_expiration_enforced)
            end

            unless License.ai_features_available?
              attrs = attrs.except(:duo_features_enabled, :lock_duo_features_enabled)
            end

            unless ::GitlabSubscriptions::AddOnPurchase.exists_for_unit_primitive?(:complete_code, :instance)
              attrs = attrs.except(:disabled_direct_code_suggestions)
            end

            unless ::License.feature_available?(:cluster_receptive_agents)
              attrs = attrs.except(:receptive_cluster_agents_enabled)
            end

            unless ::Gitlab::Saas.feature_available?(:pipl_compliance)
              attrs = attrs.except(:enforce_pipl_compliance)
            end

            attrs
          end
          # rubocop:enable Metrics/AbcSize
          # rubocop:enable Metrics/CyclomaticComplexity
          # rubocop:enable Metrics/PerceivedComplexity
        end
      end
    end
  end
end
