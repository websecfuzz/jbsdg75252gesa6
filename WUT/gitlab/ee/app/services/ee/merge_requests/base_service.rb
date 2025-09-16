# frozen_string_literal: true

module EE
  module MergeRequests
    module BaseService
      extend ::Gitlab::Utils::Override

      private

      attr_accessor :blocking_merge_requests_params, :suggested_reviewer_ids

      def assign_duo_as_reviewer(merge_request)
        project = merge_request.project
        return unless project.auto_duo_code_review_enabled
        return unless project.duo_enterprise_features_available?

        if merge_request.ai_review_merge_request_allowed?(current_user)
          duo_bot = ::Users::Internal.duo_code_review_bot
          merge_request.reviewers << duo_bot unless merge_request.reviewer_ids.include?(duo_bot.id)
        else
          merge_request.duo_code_review_attempted = true
        end
      end

      override :handle_reviewers_change
      def handle_reviewers_change(merge_request, old_reviewers)
        super
        new_reviewers = merge_request.reviewers - old_reviewers
        capture_suggested_reviewers_accepted(merge_request)
        set_requested_changes(merge_request, new_reviewers) if new_reviewers.any?
        request_duo_code_review(merge_request) if new_reviewers.any?(&:duo_code_review_bot?)
      end

      override :execute_external_hooks
      def execute_external_hooks(merge_request, merge_data)
        merge_request.project.execute_external_compliance_hooks(merge_data)
      end

      override :filter_params
      def filter_params(merge_request)
        unless current_user.can?(:update_approvers, merge_request)
          params.delete(:approvals_before_merge)
          params.delete(:approver_ids)
          params.delete(:approver_group_ids)
        end

        # Only users who have permission to merge can update this value
        params.delete(:override_requested_changes) unless merge_request.can_be_merged_by?(current_user)

        self.params = ApprovalRules::ParamsFilteringService.new(merge_request, current_user, params).execute

        self.blocking_merge_requests_params =
          ::MergeRequests::UpdateBlocksService.extract_params!(params)

        super
      end

      override :filter_suggested_reviewers
      def filter_suggested_reviewers
        suggested_reviewer_ids_from_params = params.delete(:suggested_reviewer_ids)
        return if suggested_reviewer_ids_from_params.blank?

        self.suggested_reviewer_ids = suggested_reviewer_ids_from_params & params[:reviewer_ids]
      end

      def set_requested_changes(merge_request, new_reviewers)
        requested_changes_users = merge_request.requested_changes_for_users(new_reviewers.map(&:id))

        merge_request.merge_request_reviewers_with(requested_changes_users.select(:user_id))
          .update_all(state: :requested_changes)
      end

      override :request_duo_code_review
      def request_duo_code_review(merge_request)
        # NOTE: Skip if the merge_request has just been created and its diffs are not yet ready since
        #   they are generated asynchronously.
        #   Duo code review will then be triggered in AfterCreateService after diffs are created.
        return unless merge_request.merge_request_diff.persisted?
        return if merge_request.merge_request_diff.empty?
        return unless merge_request.ai_review_merge_request_allowed?(current_user)

        ::Llm::ReviewMergeRequestService.new(current_user, merge_request).execute
      end

      def reset_approvals?(merge_request, _newrev)
        delete_approvals?(merge_request) || merge_request.target_project.project_setting.selective_code_owner_removals
      end

      def delete_approvals?(merge_request)
        merge_request.target_project.reset_approvals_on_push ||
          merge_request.policy_approval_settings.fetch(:remove_approvals_with_new_commit, false)
      end

      def delete_approvals(merge_request, patch_id_sha: nil, cause: nil)
        approvals = merge_request.approvals
        approvals = filter_approvals(approvals, patch_id_sha) if patch_id_sha.present?
        approver_ids = approvals.map(&:user_id)

        approvals.delete_all

        # In case there is still a temporary flag on the MR
        merge_request.approval_state.expire_unapproved_key!

        merge_request.batch_update_reviewer_state(approver_ids, 'unapproved')

        trigger_merge_request_merge_status_updated(merge_request)
        trigger_merge_request_approval_state_updated(merge_request)
        publish_approvals_reset_event(merge_request, cause, approver_ids)
      end

      def filter_approvals(approvals, patch_id_sha)
        approvals.with_invalid_patch_id_sha(patch_id_sha)
      end

      def all_approvers(merge_request)
        merge_request.overall_approvers(exclude_code_owners: true)
      end

      def publish_approvals_reset_event(merge_request, cause, approver_ids)
        return if cause.nil?
        return if approver_ids.empty?

        ::Gitlab::EventStore.publish(
          ::MergeRequests::ApprovalsResetEvent.new(
            data: {
              current_user_id: current_user.id,
              merge_request_id: merge_request.id,
              cause: cause.to_s,
              approver_ids: approver_ids
            }
          )
        )
      end

      def capture_suggested_reviewers_accepted(merge_request)
        return if suggested_reviewer_ids.blank?

        ::MergeRequests::CaptureSuggestedReviewersAcceptedWorker
          .perform_async(merge_request.id, suggested_reviewer_ids)
      end

      def audit_security_policy_branch_bypass(merge_request)
        matching_policies = merge_request.security_policies_with_branch_exceptions

        return if matching_policies.empty?

        matching_policies.each do |policy|
          next unless ::Feature.enabled?(:approval_policy_branch_exceptions, policy.security_policy_management_project)

          log_audit_event(
            merge_request,
            'merge_request_branch_bypassed_by_security_policy',
            "Approvals bypassed by security policy #{policy.name}"
          )
        end
      end

      def log_audit_event(merge_request, event_name, message)
        audit_context = {
          name: event_name,
          author: current_user,
          scope: merge_request.target_project,
          target: merge_request,
          message: message,
          target_details:
            { iid: merge_request.iid,
              id: merge_request.id,
              source_branch: merge_request.source_branch,
              target_branch: merge_request.target_branch }
        }

        if event_name == 'merge_request_merged_by_project_bot'
          audit_context[:target_details][:merge_commit_sha] = merge_request.merge_commit_sha
        end

        ::Gitlab::Audit::Auditor.audit(audit_context)
      end
    end
  end
end
