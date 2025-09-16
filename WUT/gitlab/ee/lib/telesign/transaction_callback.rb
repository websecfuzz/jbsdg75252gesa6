# frozen_string_literal: true

module Telesign
  class TransactionCallback
    include Gitlab::Utils::StrongMemoize

    attr_reader :request, :payload

    AUTHORIZATION_SCHEME = 'TSA'

    def initialize(request, params)
      @request = request
      @payload = Telesign::TransactionCallbackPayload.new(params)
    end

    def valid?
      return false unless signature.present?

      # https://developer.telesign.com/enterprise/docs/authenticate-callbacks
      api_key = Base64.decode64(::Gitlab::CurrentSettings.telesign_api_key)
      digest = Base64.encode64(OpenSSL::HMAC.digest("SHA256", api_key, request.raw_post))

      ActiveSupport::SecurityUtils.secure_compare(signature.strip, digest.strip)
    end
    strong_memoize_attr :valid?

    def log
      return unless valid?

      ::Gitlab::AppJsonLogger.info(
        class: self.class.name,
        username: user&.username,
        message: 'IdentityVerification::Phone',
        event: 'Telesign transaction status update',
        telesign_reference_id: payload.reference_id,
        telesign_status: payload.status,
        telesign_status_updated_on: payload.status_updated_on,
        telesign_errors: payload.errors
      )

      track_status_update_event
    end

    def user
      return unless valid?

      phone_number_validation_record&.user
    end

    private

    def phone_number_validation_record
      Users::PhoneNumberValidation.by_reference_id(payload.reference_id)
    end
    strong_memoize_attr :phone_number_validation_record

    def track_status_update_event
      return unless phone_number_validation_record

      event = payload.failed_delivery? ? 'telesign_sms_delivery_failed' : 'telesign_sms_delivery_success'

      Gitlab::Tracking.event(
        'IdentityVerification::Phone',
        event,
        user: user,
        extra: { country_code: phone_number_validation_record.country, status: payload.status }
      )
    end

    def telesign_customer_id
      ::Gitlab::CurrentSettings.telesign_customer_xid
    end

    def signature
      return unless authorization

      scheme, customer_id_and_signature = authorization.split(' ')
      return unless scheme == AUTHORIZATION_SCHEME
      return unless customer_id_and_signature

      customer_id, signature = customer_id_and_signature.split(':')
      return unless ActiveSupport::SecurityUtils.secure_compare(telesign_customer_id, customer_id)

      @signature ||= signature
    end
    strong_memoize_attr :signature

    def authorization
      request.headers['Authorization']
    end
    strong_memoize_attr :authorization
  end
end
