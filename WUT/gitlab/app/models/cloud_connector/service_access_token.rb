# frozen_string_literal: true

module CloudConnector
  class ServiceAccessToken < ApplicationRecord
    include Gitlab::EncryptedAttribute

    self.table_name = 'service_access_tokens'

    scope :expired, -> { where('expires_at < :now', now: Time.current) }
    scope :active, -> { where('expires_at > :now', now: Time.current) }

    attr_encrypted :token,
      mode: :per_attribute_iv,
      key: :db_key_base_32,
      algorithm: 'aes-256-gcm',
      encode: false,
      encode_iv: false

    validates :token, :expires_at, presence: true

    def expired?
      expires_at.past?
    end

    def refresh_required?
      expires_at < 2.days.from_now
    end
  end
end
