# frozen_string_literal: true

module EE
  module API
    module Entities
      module ApplicationSetting
        extend ActiveSupport::Concern

        prepended do
          expose(*EE::ApplicationSettingsHelper.repository_mirror_attributes, if: ->(_instance, _options) do
            ::License.feature_available?(:repository_mirrors)
          end)
          expose(*EE::ApplicationSettingsHelper.merge_request_appovers_rules_attributes, if: ->(_instance, _options) do
            ::License.feature_available?(:admin_merge_request_approvers_rules)
          end)
          expose(*EE::ApplicationSettingsHelper.password_complexity_attributes, if: ->(_instance, _options) do
            ::License.feature_available?(:password_complexity)
          end)
          expose :email_additional_text, if: ->(_instance, _opts) { ::License.feature_available?(:email_additional_text) }
          expose :file_template_project_id, if: ->(_instance, _opts) { ::License.feature_available?(:custom_file_templates) }
          expose :default_project_deletion_protection, if: ->(_instance, _opts) { ::License.feature_available?(:default_project_deletion_protection) }
          expose :disable_personal_access_tokens, if: ->(_instance, _opts) { ::License.feature_available?(:disable_personal_access_tokens) }
          expose :updating_name_disabled_for_users, if: ->(_instance, _opts) { ::License.feature_available?(:disable_name_update_for_users) }
          expose :maven_package_requests_forwarding, if: ->(_instance, _opts) { ::License.feature_available?(:package_forwarding) }
          expose :npm_package_requests_forwarding, if: ->(_instance, _opts) { ::License.feature_available?(:package_forwarding) }
          expose :virtual_registries_endpoints_api_limit, if: ->(_instance, _opts) { ::License.feature_available?(:packages_virtual_registry) }
          expose :secret_push_protection_available, if: ->(_instance, _opts) { ::License.feature_available?(:secret_push_protection) }
          expose :secret_push_protection_available,
            if: ->(_instance, _opts) { ::License.feature_available?(:secret_push_protection) },
            as: :pre_receive_secret_detection_enabled
          expose :pypi_package_requests_forwarding, if: ->(_instance, _opts) { ::License.feature_available?(:package_forwarding) }
          expose :group_owners_can_manage_default_branch_protection, if: ->(_instance, _opts) { ::License.feature_available?(:default_branch_protection_restriction_in_groups) }
          expose :maintenance_mode, if: ->(_instance, _opts) { RegistrationFeatures::MaintenanceMode.feature_available? }
          expose :maintenance_mode_message, if: ->(_instance, _opts) { RegistrationFeatures::MaintenanceMode.feature_available? }
          expose :service_access_tokens_expiration_enforced, if: ->(_instance, _opts) { ::License.feature_available?(:service_accounts) }
          expose :git_two_factor_session_expiry, if: ->(_instance, _opts) { License.feature_available?(:git_two_factor_enforcement) && ::Feature.enabled?(:two_factor_for_cli) }
          expose(*EE::ApplicationSettingsHelper.git_abuse_rate_limit_attributes, if: ->(_instance, _options) do
            ::License.feature_available?(:git_abuse_rate_limit)
          end)
          expose(*EE::ApplicationSettingsHelper.delete_unconfirmed_users_attributes, if: ->(_instance, _options) do
            ::License.feature_available?(:delete_unconfirmed_users)
          end)
          expose :make_profile_private, if: ->(_instance, _opts) do
            ::License.feature_available?(:disable_private_profiles)
          end
          expose :duo_features_enabled, if: ->(_instance, _opts) { ::License.ai_features_available? }
          expose :lock_duo_features_enabled, if: ->(_instance, _opts) { ::License.ai_features_available? }
          expose :enabled_expanded_logging, if: ->(_instance, _opts) { ::License.ai_features_available? }
          expose :disabled_direct_code_suggestions, if: ->(_instance, _opts) { ::GitlabSubscriptions::AddOnPurchase.exists_for_unit_primitive?(:complete_code, :instance) }
          expose :allow_top_level_group_owners_to_create_service_accounts, if: ->(_instance, _opts) { ::License.feature_available?(:service_accounts) }
        end
      end
    end
  end
end
