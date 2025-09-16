# frozen_string_literal: true

module MergeRequests
  module Mergeability
    class CheckConflictStatusService < CheckBaseService
      identifier :conflict
      description 'Checks whether the merge request has a conflict'

      def execute
        if merge_request.can_be_merged?
          success
        elsif merge_request.cannot_be_merged?
          failure
        else
          checking
        end
      end

      def skip?
        params[:skip_conflict_check].present?
      end

      def cacheable?
        false
      end
    end
  end
end
