# frozen_string_literal: true

# This model records member role assignment to a user in groups through:
# - Group membership
# - Group sharing
#
# shared_with_group_id is nil for assigments through group membership.
#
# For assignments through group sharing group_id points to the shared group
# (group_group_link.shared_group) while shared_with_group_id ==
# group_group_link.shared_with_group_id. The shared_with_group_id column serves
# as a differentiator between different types of member role assignments as well
# as a way to easily delete records when the matching group_group_link record is
# deleted or the user's membership to shared_with_group is removed.
module Authz
  class UserGroupMemberRole < ApplicationRecord
    belongs_to :user
    belongs_to :group, class_name: '::Group'
    belongs_to :shared_with_group, class_name: '::Group'
    belongs_to :member_role

    validates :user, presence: true, uniqueness: { scope: %i[group_id shared_with_group_id] }
    validates :group, presence: true
    validates :member_role, presence: true

    def self.for_user_in_group_and_shared_groups(user, group)
      direct_membership = where(user: user, group: group, shared_with_group: nil)
      shared_group_membership = where(user: user, shared_with_group: group)

      from(
        Arel::Nodes::TableAlias.new(
          Arel::Nodes::UnionAll.new(direct_membership.arel, shared_group_membership.arel),
          table_name
        )
      )
    end

    def self.in_shared_group(shared_group, shared_with_group)
      where(group: shared_group, shared_with_group: shared_with_group)
    end

    def self.delete_all_with_id(ids)
      where(id: ids).delete_all
    end

    def self.for_user_in_group(user, group)
      # Member role assigned to the user in the given group through membership.
      # `shared_with_group: nil` condition is added to exclude member role
      # assigments in the given group through an invited group.
      find_by(user: user, group: group, shared_with_group: nil)
    end
  end
end
