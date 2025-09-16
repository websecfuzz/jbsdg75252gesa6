# frozen_string_literal: true

module Gitlab
  module Auth
    module Saml
      class SsoState
        SESSION_STORE_KEY = :active_instance_sso_sign_ins
        DEFAULT_PROVIDER_ID = 'default'

        attr_reader :provider_id

        def initialize(provider_id: DEFAULT_PROVIDER_ID)
          @provider_id = provider_id.to_s.downcase.strip
        end

        def sessionless?
          !active_session_data.initiated?
        end

        def active?
          sessionless? || last_signin_at
        end

        def update_active(time: Time.current, session_not_on_or_after: nil)
          active_session_data[provider_id] ||= {}
          active_session_data[provider_id]['last_signin_at'] = time
          active_session_data[provider_id]['session_not_on_or_after'] = session_not_on_or_after
        end

        # We will override value of cutoff if session_not_on_or_after attribute is present
        def active_since?(cutoff)
          return true if sessionless?
          return false unless active?

          return saml_session_active? if session_not_on_or_after_value.present?

          cutoff ? last_signin_at >= cutoff : active?
        end

        private

        def session_not_on_or_after_value
          return unless Feature.enabled?(:saml_timeout_supplied_by_idp_override, :instance)
          return if active_session_data[provider_id].nil?

          active_session_data[provider_id]["session_not_on_or_after"]
        end

        def active_session_data
          Gitlab::NamespacedSessionStore.new(SESSION_STORE_KEY)
        end

        def last_signin_at
          return if active_session_data[provider_id].nil?

          active_session_data[provider_id]['last_signin_at']
        end

        def saml_session_active?
          return false unless session_not_on_or_after_value.present?

          # Compare current time with SAML session expiry
          Time.current <= session_not_on_or_after_value
        end
      end
    end
  end
end
