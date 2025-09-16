# frozen_string_literal: true

module MergeRequests
  class ExecuteApprovalHooksWorker
    include Gitlab::EventStore::Subscriber

    data_consistency :always
    feature_category :code_review_workflow
    urgency :low
    idempotent!

    # MergeRequests::ExecuteApprovalHooksService execute webhooks which are treated as external dependencies
    worker_has_external_dependencies!

    def handle_event(event)
      current_user_id = event.data[:current_user_id]
      merge_request_id = event.data[:merge_request_id]
      current_user = User.find_by_id(current_user_id)

      unless current_user
        logger.info(structured_payload(message: 'Current user not found.', current_user_id: current_user_id))
        return
      end

      merge_request = MergeRequest.find_by_id(merge_request_id)

      unless merge_request
        logger.info(structured_payload(message: 'Merge request not found.', merge_request_id: merge_request_id))
        return
      end

      ::MergeRequests::ExecuteApprovalHooksService
        .new(project: merge_request.project, current_user: current_user)
        .execute(merge_request)
    end
  end
end
