# frozen_string_literal: true

module SystemNotes # rubocop:disable Gitlab/BoundedContexts -- SystemNotes module already exists and holds the other services
  class ComplianceViolationsService < ::SystemNotes::BaseService
    def change_violation_status
      new_status = noteable.status.humanize
      create_note(NoteSummary.new(noteable, project, author, "changed status to #{new_status}", action: 'status'))
    end
  end
end
