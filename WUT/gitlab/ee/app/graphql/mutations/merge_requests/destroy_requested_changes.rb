# frozen_string_literal: true

module Mutations
  module MergeRequests
    class DestroyRequestedChanges < Base
      graphql_name 'MergeRequestDestroyRequestedChanges'

      def resolve(project_path:, iid:)
        merge_request = authorized_find!(project_path: project_path, iid: iid)

        result = ::MergeRequests::DestroyRequestedChangesService.new(
          project: merge_request.project,
          current_user: current_user
        ).execute(merge_request)

        {
          merge_request: merge_request,
          errors: Array(result[:message])
        }
      end
    end
  end
end
