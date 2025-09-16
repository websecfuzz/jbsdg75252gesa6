# frozen_string_literal: true

module Authz
  module UserGroupMemberRoles
    class DestroyForGroupService < BaseService
      attr_reader :user, :group

      def initialize(user, group)
        @user = user
        @group = group
      end

      def execute
        # Deletes one record for the target group and one for each group it was
        # invited to with an assigned member role. Expected volume: ~100 records
        # maximum.
        ids = ::Authz::UserGroupMemberRole.for_user_in_group_and_shared_groups(user, group).ids # rubocop: disable CodeReuse/ActiveRecord -- Very specific use case.

        ::Authz::UserGroupMemberRole.delete_all_with_id(ids)
      end
    end
  end
end
