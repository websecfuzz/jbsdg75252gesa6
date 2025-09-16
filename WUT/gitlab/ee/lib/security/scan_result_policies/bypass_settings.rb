# frozen_string_literal: true

module Security
  module ScanResultPolicies
    class BypassSettings
      include Gitlab::Utils::StrongMemoize

      def initialize(bypass_settings)
        @bypass_settings = bypass_settings || {}
      end

      def access_token_ids
        bypass_settings[:access_tokens]&.pluck(:id)
      end
      strong_memoize_attr :access_token_ids

      def service_account_ids
        bypass_settings[:service_accounts]&.pluck(:id)
      end
      strong_memoize_attr :service_account_ids

      private

      attr_reader :bypass_settings
    end
  end
end
