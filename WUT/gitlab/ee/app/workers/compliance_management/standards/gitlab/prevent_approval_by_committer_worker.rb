# frozen_string_literal: true

module ComplianceManagement
  module Standards
    module Gitlab
      class PreventApprovalByCommitterWorker < BaseWorker
        data_consistency :sticky
        idempotent!
        urgency :low

        feature_category :compliance_management

        def service_class
          ComplianceManagement::Standards::Gitlab::PreventApprovalByCommitterService
        end
      end
    end
  end
end
