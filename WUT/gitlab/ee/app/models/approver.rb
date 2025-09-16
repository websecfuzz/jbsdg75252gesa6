# frozen_string_literal: true

class Approver < ApplicationRecord
  belongs_to :target, polymorphic: true
  belongs_to :user

  include ApproverMigrateHook

  validates :user, presence: true

  def find_by_user_id(user_id)
    find_by(user_id: user_id)
  end

  def member
    user
  end
end
