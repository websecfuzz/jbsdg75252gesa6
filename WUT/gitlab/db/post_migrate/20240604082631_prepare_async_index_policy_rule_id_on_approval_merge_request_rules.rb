# frozen_string_literal: true

class PrepareAsyncIndexPolicyRuleIdOnApprovalMergeRequestRules < Gitlab::Database::Migration[2.2]
  milestone '17.1'

  INDEX_NAME = 'index_approval_merge_request_rules_on_approval_policy_rule_id'

  # TODO: Index to be created synchronously as part of https://gitlab.com/gitlab-org/gitlab/-/merge_requests/155256
  def up
    # rubocop:disable Migration/PreventIndexCreation -- large tables
    prepare_async_index :approval_merge_request_rules, :approval_policy_rule_id, name: INDEX_NAME
    # rubocop:enable Migration/PreventIndexCreation
  end

  def down
    unprepare_async_index :approval_merge_request_rules, :approval_policy_rule_id, name: INDEX_NAME
  end
end
