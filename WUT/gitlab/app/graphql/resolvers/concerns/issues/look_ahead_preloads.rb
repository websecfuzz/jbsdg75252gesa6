# frozen_string_literal: true

module Issues
  module LookAheadPreloads
    extend ActiveSupport::Concern

    prepended do
      include ::LooksAhead
    end

    private

    def unconditional_includes
      [
        {
          project: [:project_feature, :group]
        },
        :author,
        :work_item_type
      ]
    end

    def preloads
      {
        reference: { namespace: [{ parent: :route }, :route] },
        alert_management_alert: [:alert_management_alert],
        assignees: [:assignees],
        participants: Issue.participant_includes,
        timelogs: [:timelogs],
        customer_relations_contacts: { customer_relations_contacts: [:group] },
        escalation_status: [:incident_management_issuable_escalation_status],
        type: :work_item_type
      }
    end
  end
end

Issues::LookAheadPreloads.prepend_mod
