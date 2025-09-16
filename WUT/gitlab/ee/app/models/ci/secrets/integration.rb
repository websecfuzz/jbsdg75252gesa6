# frozen_string_literal: true

module Ci
  module Secrets
    class Integration
      PROVIDER_TYPE_MAP = {
        "azure_key_vault" => :azure_key_vault,
        "akeyless" => :akeyless,
        "gcp_secret_manager" => :gcp_secret_manager,
        "vault" => :hashicorp_vault,
        "gitlab_secrets_manager" => :gitlab_secrets_manager,
        "aws_secrets_manager" => :aws
      }.freeze

      def initialize(variables:, project:)
        @variables = variables
        @project = project
      end

      def secrets_provider?(secrets)
        candidates = PROVIDER_TYPE_MAP.values.select { |provider| send(:"#{provider}?") } # rubocop:disable GitlabSecurity/PublicSend -- metaprogramming

        # No providers are enabled.
        return false if candidates.empty?

        # No secrets were provided; vacuously this means all provided secrets
        # have a provider. This is deferred so global enablement logic can be
        # checked independently of secrets value.
        return true if secrets.nil? || secrets.empty?

        # If none of the secrets lacks an enabled provider, we're good.
        secrets.none? do |(_, secret_info)|
          secret_info.any? do |(provider_key, _)|
            PROVIDER_TYPE_MAP.has_key?(provider_key) &&
              candidates.exclude?(PROVIDER_TYPE_MAP[provider_key])
          end
        end
      end

      private

      attr_reader :variables

      def gcp_secret_manager?
        variables['GCP_PROJECT_NUMBER']&.value.present? &&
          variables['GCP_WORKLOAD_IDENTITY_FEDERATION_POOL_ID']&.value.present? &&
          variables['GCP_WORKLOAD_IDENTITY_FEDERATION_PROVIDER_ID']&.value.present?
      end

      def azure_key_vault?
        variables['AZURE_KEY_VAULT_SERVER_URL']&.value.present? &&
          variables['AZURE_CLIENT_ID']&.value.present? &&
          variables['AZURE_TENANT_ID']&.value.present?
      end

      def hashicorp_vault?
        variables['VAULT_SERVER_URL']&.value.present?
      end

      def akeyless?
        variables['AKEYLESS_ACCESS_ID']&.value.present?
      end

      def aws?
        variables['AWS_REGION']&.value.present?
      end

      def gitlab_secrets_manager?
        # TODO: figure out context for whether GitLab Secrets Manager is
        # globally enabled on this instance.
        SecretsManagement::ProjectSecretsManager.find_by_project_id(@project.id)&.active?
      end
    end
  end
end
