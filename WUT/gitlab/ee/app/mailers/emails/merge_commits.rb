# frozen_string_literal: true

module Emails
  module MergeCommits
    def merge_commits_csv_email(user, group, csv_data, filename)
      @group = group

      attachments[filename] = { content: csv_data, mime_type: 'text/csv' }
      email_with_layout(
        to: user.notification_email_for(group),
        subject: subject(Date.current.iso8601 + s_("ComplianceChainOfCustody| Chain of custody export")))
    end
  end
end
