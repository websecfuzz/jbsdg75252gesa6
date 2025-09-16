# frozen_string_literal: true

module Authz
  module UserGroupMemberRoles
    class DestroyForSharedGroupService < BaseService
      attr_reader :shared_group, :shared_with_group

      def initialize(shared_group, shared_with_group)
        @shared_group = shared_group
        @shared_with_group = shared_with_group
      end

      def execute
        ::Authz::UserGroupMemberRole
          .in_shared_group(shared_group, shared_with_group)
          .delete_all
      end
    end
  end
end
