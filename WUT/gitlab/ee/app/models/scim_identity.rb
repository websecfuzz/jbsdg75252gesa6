# frozen_string_literal: true

class ScimIdentity < ApplicationRecord
  include Sortable
  include CaseSensitivity
  include ScimPaginatable

  belongs_to :group, optional: true
  belongs_to :user

  validates :user, presence: true, uniqueness: { scope: [:group_id] }
  validates :extern_uid, presence: true,
    uniqueness: { case_sensitive: false, scope: [:group_id] }

  scope :for_instance, -> { where(group: nil) }
  scope :for_user, ->(user) { where(user: user) }
  scope :with_extern_uid, ->(extern_uid) { iwhere(extern_uid: extern_uid) }
  scope :with_user_ids, ->(user_ids) { where(user_id: user_ids) }

  after_commit :sync_records, on: %i[create update]

  def sync_records
    Authn::SyncScimIdentityRecordWorker.perform_async({ 'scim_identity_id' => id })
  end
end
