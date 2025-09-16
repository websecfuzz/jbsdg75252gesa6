# frozen_string_literal: true

module EE
  # Project EE mixin
  #
  # This module is intended to encapsulate EE-specific model logic
  # and be prepended in the `Deployment` model
  module Deployment
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override

    prepended do
      include UsageStatistics

      delegate :needs_approval?, to: :environment
      delegate :allow_pipeline_trigger_approve_deployment, to: :project

      has_many :approvals, class_name: 'Deployments::Approval'

      scope :with_approvals, -> { preload(approvals: [:user]) }

      Dora::Watchers.mount(self)

      state_machine :status do
        after_transition any => :running do |deployment|
          deployment.run_after_commit do
            ::Environments::Deployments::AuditService.new(self).execute
          end
        end
      end
    end

    def waiting_for_approval?
      pending_approval_count > 0
    end

    def pending_approval_count
      return 0 unless environment.protected?

      approval_summary.total_pending_approval_count
    end

    def approval_summary
      strong_memoize(:approval_summary) do
        ::Deployments::ApprovalSummary.new(deployment: self)
      end
    end

    def approved?
      approval_summary.status == ::Deployments::ApprovalSummary::STATUS_APPROVED
    end
  end
end
