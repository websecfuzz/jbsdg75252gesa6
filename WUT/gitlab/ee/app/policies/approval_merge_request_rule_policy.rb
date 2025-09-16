# frozen_string_literal: true

class ApprovalMergeRequestRulePolicy < BasePolicy
  delegate { @subject.merge_request }

  condition(:editable) do
    if Feature.enabled?(:ensure_consistent_editing_rule, @subject.merge_request.project)
      @subject.editable_by_user?(@user) &&
        can?(:update_merge_request, @subject.merge_request)
    else
      can?(:update_merge_request, @subject.merge_request) && @subject.user_defined?
    end
  end

  rule { editable }.enable :edit_approval_rule

  rule { can?(:read_merge_request) }.enable :read_approval_rule
end
