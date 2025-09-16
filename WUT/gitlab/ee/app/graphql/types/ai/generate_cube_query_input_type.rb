# frozen_string_literal: true

module Types
  module Ai
    class GenerateCubeQueryInputType < BaseMethodInputType
      graphql_name 'AiGenerateCubeQueryInput'

      argument :question, GraphQL::Types::String,
        required: true,
        description: 'Question to ask a project\'s data.'
    end
  end
end
