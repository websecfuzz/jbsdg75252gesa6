# frozen_string_literal: true

module Types
  module Geo
    # rubocop:disable Graphql/AuthorizeTypes -- because it is included
    class LfsObjectRegistryType < BaseObject
      graphql_name 'LfsObjectRegistry'
      description 'Represents the Geo sync and verification state of an LFS object'

      include ::Types::Geo::RegistryType

      field :lfs_object_id, GraphQL::Types::ID, null: false, description: 'ID of the LFS object.'
    end
    # rubocop:enable Graphql/AuthorizeTypes
  end
end
