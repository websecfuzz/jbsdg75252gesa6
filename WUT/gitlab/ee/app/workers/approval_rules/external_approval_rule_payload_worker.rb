# frozen_string_literal: true

module ApprovalRules
  class ExternalApprovalRulePayloadWorker
    include ApplicationWorker

    data_consistency :always

    sidekiq_options retry: 3
    idempotent!

    feature_category :security_policy_management

    def perform(rule_id, data)
      rule = MergeRequests::ExternalStatusCheck.find(rule_id)

      ExternalStatusChecks::DispatchService.new(rule, data).execute
    end
  end
end
