# frozen_string_literal: true

module ExternalStatusChecks
  class UpdateService < BaseService
    ERROR_MESSAGE = 'Failed to update external status check'

    def execute(skip_authorization: false)
      return unauthorized_error_response unless skip_authorization || can_update_external_status_check?

      if with_audit_logged(external_status_check, 'update_status_check') do
        external_status_check.update(resource_params)
      end
        log_audit_event

        ServiceResponse.success(payload: { external_status_check: external_status_check })
      else
        ServiceResponse.error(
          message: ERROR_MESSAGE,
          payload: { errors: external_status_check.errors.full_messages },
          http_status: :unprocessable_entity
        )
      end
    end

    private

    def can_update_external_status_check?
      current_user.can?(:manage_merge_request_settings, container)
    end

    def resource_params
      params.slice(:name, :shared_secret, :external_url, :protected_branch_ids)
    end

    def external_status_check
      @external_status_check ||= container.external_status_checks.find(params[:check_id])
    end

    def unauthorized_error_response
      ServiceResponse.error(
        message: ERROR_MESSAGE,
        payload: { errors: ['Not allowed'] },
        http_status: :unauthorized
      )
    end

    def log_audit_event
      MergeRequests::ExternalStatusCheckChangesAuditor.new(current_user, external_status_check).execute
    end
  end
end
