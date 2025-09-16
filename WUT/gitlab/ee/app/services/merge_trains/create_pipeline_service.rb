# frozen_string_literal: true

module MergeTrains
  class CreatePipelineService < BaseService
    def execute(merge_request, previous_ref, create_mergeable_ref)
      validation_status = validate(merge_request)
      return validation_status unless validation_status[:status] == :success

      merge_status = create_train_ref(merge_request, previous_ref, create_mergeable_ref)
      return error(merge_status[:message]) unless merge_status[:status] == :success

      create_pipeline(merge_request, merge_status)
    end

    private

    def validate(merge_request)
      return error('merge trains is disabled') unless merge_request.project.merge_trains_enabled?
      return error('merge request is not on a merge train') unless merge_request.on_train?

      success
    end

    def create_train_ref(merge_request, previous_ref, create_mergeable_ref)
      return error('previous ref is not specified') unless previous_ref

      if create_mergeable_ref
        ::MergeTrains::CreateRefService.new(
          current_user: merge_request.merge_user,
          merge_request: merge_request,
          source_sha: merge_request.diff_head_sha,
          first_parent_ref: previous_ref
        ).execute.to_h.transform_keys do |key|
          # TODO: Remove this transformation with https://gitlab.com/gitlab-org/gitlab/-/issues/455421
          case key
          when :commit_sha then :commit_id
          when :source_sha then :source_id
          when :target_sha then :target_id
          else key
          end
        end
      else
        # TODO: Remove in https://gitlab.com/gitlab-org/gitlab/-/issues/455421
        ::MergeRequests::MergeToRefService.new(
          project: merge_request.target_project,
          current_user: merge_request.merge_user,
          params: {
            target_ref: merge_request.train_ref_path,
            first_parent_ref: previous_ref,
            commit_message: MergeTrains::MergeCommitMessage.legacy_value(merge_request, previous_ref)
          }
        ).execute(merge_request)
      end
    end

    def create_pipeline(merge_request, merge_status)
      response = ::Ci::CreatePipelineService.new(merge_request.target_project, merge_request.merge_user,
        ref: merge_request.train_ref_path,
        checkout_sha: merge_status[:commit_id],
        target_sha: merge_status[:target_id],
        source_sha: merge_status[:source_id])
        .execute(:merge_request_event, merge_request: merge_request)

      return error(response.message) if response.error? && !response.payload.persisted?

      success(pipeline: response.payload)
    end
  end
end
