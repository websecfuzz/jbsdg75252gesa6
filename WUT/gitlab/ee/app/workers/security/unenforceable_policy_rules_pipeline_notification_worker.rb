# frozen_string_literal: true

module Security
  class UnenforceablePolicyRulesPipelineNotificationWorker
    include ApplicationWorker

    idempotent!
    data_consistency :sticky
    feature_category :security_policy_management

    # Value is based on 99.99th percentile of duration of the policy-related workers:
    # https://log.gprd.gitlab.net/app/lens#/edit/b7df98a8-dea6-461b-b32c-95bd9ecf0ac8?_g=(filters%3A!()%2CrefreshInterval%3A(pause%3A!t%2Cvalue%3A60000)%2Ctime%3A(from%3Anow-1w%2Cto%3Anow))
    UNBLOCK_PENDING_VIOLATIONS_TIMEOUT = 90.seconds

    def perform(pipeline_id)
      pipeline = ::Ci::Pipeline.find_by_id(pipeline_id)
      return unless pipeline
      # Worker is enqueued in MergeRequests::AfterCreate to unblock merge check if pipeline finishes
      # before MR is created. If pipeline is still running, we exit early
      return unless pipeline.complete_or_manual?
      # Skip child pipelines to avoid noise and premature approval rule updates.
      # It's enough to notify when parent finishes because it checks artifacts in all related pipelines for given `sha`.
      return if pipeline.parent_pipeline?

      project = pipeline.project
      return unless project.licensed_feature_available?(:security_orchestration_policies)
      return if project.approval_rules.with_scan_result_policy_read.none?

      related_merge_requests = pipeline.opened_merge_requests_with_head_sha
      return if related_merge_requests.none?

      if ::Feature.enabled?(:policy_mergability_check, project)
        Security::ScanResultPolicies::UnblockPendingMergeRequestViolationsWorker
          .perform_in(UNBLOCK_PENDING_VIOLATIONS_TIMEOUT, pipeline_id)
      end

      related_merge_requests.each do |merge_request|
        Security::UnenforceablePolicyRulesNotificationService.new(merge_request).execute
      end
    end
  end
end
