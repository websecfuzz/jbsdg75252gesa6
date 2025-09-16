# frozen_string_literal: true

module MergeRequests
  class ApprovalRulePolicy < BasePolicy
    condition(:project_origin, scope: :subject, score: 0) { @subject.originates_from_project? }
    condition(:project_readable) { can?(:read_project, @subject.project) }
    condition(:project_editable) { can?(:admin_project, @subject.project) }

    condition(:merge_request_origin, scope: :subject, score: 0) { @subject.originates_from_merge_request? }
    condition(:merge_request_readable) { can?(:read_merge_request, @subject.merge_request) }
    condition(:merge_request_editable) do
      if Feature.enabled?(:ensure_consistent_editing_rule, @subject.merge_request&.project)
        @subject.editable_by_user?(@user) &&
          can?(:update_merge_request, @subject.merge_request)
      else
        can?(:update_merge_request, @subject.merge_request) && @subject.user_defined?
      end
    end

    rule { project_origin & project_readable }.enable :read_approval_rule
    rule { project_origin & project_editable }.enable :edit_approval_rule
    rule { merge_request_origin & merge_request_readable }.enable :read_approval_rule
    rule { merge_request_origin & merge_request_editable }.enable :edit_approval_rule
  end
end
