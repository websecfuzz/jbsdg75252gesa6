# frozen_string_literal: true

# rubocop: disable Gitlab/NamespacedClass
class AccessTokenEntityBase < API::Entities::PersonalAccessTokenWithLastUsedIps
  expose :expired?, as: :expired
  expose :expires_soon?, as: :expires_soon
end
# rubocop: enable Gitlab/NamespacedClass
