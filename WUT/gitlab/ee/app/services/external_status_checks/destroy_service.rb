# frozen_string_literal: true

module ExternalStatusChecks
  class DestroyService < BaseService
    ERROR_MESSAGE = 'Failed to destroy external status check'

    def execute(external_status_check, skip_authorization: false)
      return unauthorized_error_response unless skip_authorization || can_destroy_external_status_check?

      if with_audit_logged(external_status_check, 'delete_status_check') { external_status_check.destroy }
        ServiceResponse.success
      else
        ServiceResponse.error(
          message: ERROR_MESSAGE,
          payload: { errors: external_status_check.errors.full_messages },
          http_status: :unprocessable_entity
        )
      end
    end

    private

    def can_destroy_external_status_check?
      current_user.can?(:manage_merge_request_settings, container)
    end

    def unauthorized_error_response
      ServiceResponse.error(
        message: ERROR_MESSAGE,
        payload: { errors: ['Not allowed'] },
        http_status: :unauthorized
      )
    end
  end
end
