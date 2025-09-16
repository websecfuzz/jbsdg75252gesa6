# frozen_string_literal: true

module SystemNotes
  class MergeTrainService < ::SystemNotes::BaseService
    # Called when 'merge train' is executed
    def enqueue(merge_train)
      index = merge_train.index

      body = if index == 0
               "started a #{merge_train_link}"
             else
               "added this merge request to the #{merge_train_link} at position #{index + 1}"
             end

      create_note(NoteSummary.new(noteable, project, author, body, action: 'merge'))
    end

    # Called when 'merge train' is canceled
    def cancel
      body = 'removed this merge request from the merge train'

      create_note(NoteSummary.new(noteable, project, author, body, action: 'merge'))
    end

    # Called when 'merge train' is aborted
    def abort(reason)
      ::TodoService.new.merge_train_removed(noteable)

      ##
      # TODO: Abort message should be sent by the system, not a particular user.
      # See https://gitlab.com/gitlab-org/gitlab/issues/29467.

      body = "removed this merge request from the merge train because #{reason}"

      create_note(NoteSummary.new(noteable, project, author, body, action: 'merge'))
    end

    # Called when 'add to merge train when checks pass' is executed
    def add_when_checks_pass(_sha)
      body = "enabled automatic add to merge train when checks pass"

      create_note(NoteSummary.new(noteable, project, author, body, action: 'merge'))
    end

    # Called when 'add to merge train when checks pass' is canceled
    def cancel_add_when_checks_pass
      body = 'cancelled automatic add to merge train'

      create_note(NoteSummary.new(noteable, project, author, body, action: 'merge'))
    end

    # Called when 'add to merge train when checks pass' is aborted
    def abort_add_when_checks_pass(reason)
      ::TodoService.new.merge_train_removed(noteable)

      ##
      # TODO: Abort message should be sent by the system, not a particular user.
      # See https://gitlab.com/gitlab-org/gitlab/issues/29467.
      body = "aborted automatic add to merge train because #{reason}"
      create_note(NoteSummary.new(noteable, project, author, body, action: 'merge'))
    end

    private

    def merge_train_link
      "[merge train](#{Rails.application.routes.url_helpers.project_merge_trains_url(project)})"
    end
  end
end
