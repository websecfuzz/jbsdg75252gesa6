# frozen_string_literal: true

module Arkose
  class Logger
    attr_reader :session_token, :user, :response

    def initialize(session_token:, user: nil, verify_response: nil)
      @session_token = session_token
      @user = user
      @response = verify_response
    end

    def log_successful_token_verification
      return unless response

      logger.info(build_message('Arkose verify response'))
    end

    def log_unsolved_challenge
      return unless response

      logger.info(build_message('Challenge was not solved'))
    end

    def log_failed_token_verification
      payload = {
        session_token: session_token,
        log_data: user&.id
      }

      logger.error("Error verifying user on Arkose: #{payload}")
    end

    def log_risk_band_assignment
      return unless response && user

      logger.info(build_message('Arkose risk band assigned to user'))
    end

    private

    def logger
      Gitlab::AppLogger
    end

    def build_message(message)
      attrs = Gitlab::ApplicationContext.current.merge(message: message, response: response.response)
      attrs = attrs.merge(username: user.username, email_domain: user.email_domain) if user
      attrs.merge(arkose_payload).compact
    end

    def arkose_payload
      {
        'arkose.session_id': response.session_id,
        'arkose.session_is_legit': response.session_is_legit,
        'arkose.global_score': response.global_score,
        'arkose.global_telltale_list': response.global_telltale_list,
        'arkose.custom_score': response.custom_score,
        'arkose.custom_telltale_list': response.custom_telltale_list,
        'arkose.risk_band': response.risk_band,
        'arkose.risk_category': response.risk_category,
        'arkose.challenge_type': response.challenge_type,
        'arkose.country': response.country,
        'arkose.is_bot': response.is_bot,
        'arkose.is_vpn': response.is_vpn,
        'arkose.data_exchange_blob_received': response.data_exchange_blob_received?,
        'arkose.data_exchange_blob_decrypted': response.data_exchange_blob_decrypted?
      }
    end
  end
end
