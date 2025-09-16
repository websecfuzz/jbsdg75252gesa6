# frozen_string_literal: true

module Types
  module Issuables
    class CustomFieldSelectOptionType < BaseObject # rubocop:disable Graphql/AuthorizeTypes -- already authroized in parent entity
      graphql_name 'CustomFieldSelectOption'
      description 'Represents a custom field select option'

      field :id, ::Types::GlobalIDType[::Issuables::CustomFieldSelectOption],
        null: false, description: 'Global ID of the custom field select option.'

      field :value, GraphQL::Types::String,
        null: false, description: 'Value of the custom field select option.'
    end
  end
end
