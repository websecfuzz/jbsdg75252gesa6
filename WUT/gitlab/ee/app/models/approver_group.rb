# frozen_string_literal: true

class ApproverGroup < ApplicationRecord
  belongs_to :target, polymorphic: true
  belongs_to :group

  include ApproverMigrateHook

  validates :group, presence: true

  delegate :users, to: :group

  def self.filtered_approver_groups(approver_groups, user)
    public_or_visible_groups = Group.public_or_visible_to_user(user) # rubocop:disable Cop/GroupPublicOrVisibleToUser

    approver_groups.joins(:group).merge(public_or_visible_groups)
  end

  def member
    group
  end
end
