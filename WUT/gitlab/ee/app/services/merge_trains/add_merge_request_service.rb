# frozen_string_literal: true

module MergeTrains
  class AddMergeRequestService < BaseService
    def initialize(merge_request, current_user, params)
      super(merge_request.target_project, current_user, params)
      @merge_request = merge_request
    end

    def execute
      unless @merge_request.can_be_merged_by?(current_user)
        return ServiceResponse.error(reason: :forbidden, message: "Merge request cannot be merged by current user")
      end

      if @merge_request.auto_merge_enabled?
        return ServiceResponse.error(reason: :conflict, message: "Merge request is already set to Auto-Merge")
      end

      @merge_request.update!(squash: params[:squash]) if params[:squash]

      strategy = AutoMergeService::STRATEGY_MERGE_TRAIN

      strategy = AutoMergeService::STRATEGY_ADD_TO_MERGE_TRAIN_WHEN_CHECKS_PASS if params[:auto_merge]

      response = AutoMergeService.new(@merge_request.target_project, current_user, params.slice(:sha))
                              .execute(@merge_request, strategy)

      return ServiceResponse.error(reason: response, message: "Failed to merge") if response == :failed

      ServiceResponse.success(payload: response)
    end
  end
end
