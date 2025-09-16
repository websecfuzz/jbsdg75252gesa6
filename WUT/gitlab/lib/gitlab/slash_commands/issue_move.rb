# frozen_string_literal: true

module Gitlab
  module SlashCommands
    class IssueMove < IssueCommand
      def self.match(text)
        %r{
          \A                                 # the beginning of a string
          issue\s+move\s+                    # the command
          \#?(?<iid>\d+)\s+                  # the issue id, may preceded by hash sign
          (?:to\s+)?                         # aid the command to be much more human-ly
          (?<project_path>[^\s]+)            # named group for id of dest. project
        }x.match(text)
      end

      def self.help_message
        'issue move <issue_id> (to)? <project_path>'
      end

      def self.allowed?(project, user)
        can?(user, :admin_issue, project)
      end

      def execute(match)
        old_issue = find_by_iid(match[:iid])
        target_project = Project.find_by_full_path(match[:project_path])

        unless current_user.can?(:read_project, target_project) && old_issue
          return Gitlab::SlashCommands::Presenters::Access.new.not_found
        end

        response = ::WorkItems::DataSync::MoveService.new(
          work_item: old_issue, current_user: current_user,
          target_namespace: target_project.project_namespace
        ).execute

        return presenter(old_issue).display_move_error(response.message) if response.error?

        new_issue = response[:work_item]

        presenter(new_issue).present(old_issue)
      end

      private

      def presenter(issue)
        Gitlab::SlashCommands::Presenters::IssueMove.new(issue)
      end
    end
  end
end
