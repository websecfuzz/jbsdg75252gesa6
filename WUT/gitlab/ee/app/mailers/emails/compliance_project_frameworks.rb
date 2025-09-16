# frozen_string_literal: true

module Emails
  module ComplianceProjectFrameworks
    def compliance_project_frameworks_csv_email(user:, group:, attachment:, filename:)
      @group = group
      attachments[filename] = { content: attachment, mime_type: 'text/csv' }

      email_with_layout(
        to: user.notification_email_for(group),
        subject: subject(Date.current.iso8601 + s_("ComplianceFrameworks| Project frameworks export"))
      )
    end
  end
end
