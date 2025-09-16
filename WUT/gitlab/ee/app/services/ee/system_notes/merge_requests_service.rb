# frozen_string_literal: true

module EE
  module SystemNotes
    module MergeRequestsService
      # Called when approvals are reset
      #
      # Example Note text:
      #
      # "reset approvals from @user3, @user4, and @user5 by pushing to the branch"
      #
      # Returns the created Note object
      def approvals_reset(cause, approvers)
        # Currently limited to `:new_push` for now as other causes will be added later on.
        return unless cause == :new_push
        return if approvers.empty?

        body = "reset approvals from #{approvers.map(&:to_reference).to_sentence} by pushing to the branch"

        create_note(NoteSummary.new(noteable, project, author, body, action: 'approvals_reset'))
      end

      def override_requested_changes(event)
        body = event ? 'bypassed reviews on this merge request' : 'removed the bypass on this merge request'

        create_note(NoteSummary.new(noteable, project, author, body, action: 'override'))
      end

      def duo_code_review_started
        create_note(
          NoteSummary.new(noteable, project, author,
            s_("DuoCodeReview|is reviewing your merge request and will let you know when it's finished"))
        )
      end

      def duo_code_review_chat_started(discussion)
        discussion = discussion.convert_to_discussion! if discussion.can_convert_to_discussion?

        ::Note.create(discussion.reply_attributes.merge(
          project: project,
          author: author,
          note: s_("DuoCodeReview|is working on a reply"),
          system: true
        ))
      end
    end
  end
end
