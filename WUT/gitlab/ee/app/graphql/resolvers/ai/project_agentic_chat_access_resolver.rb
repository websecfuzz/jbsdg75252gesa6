# frozen_string_literal: true

module Resolvers
  module Ai
    class ProjectAgenticChatAccessResolver < BaseResolver
      type ::GraphQL::Types::Boolean, null: false

      alias_method :project, :object

      def resolve
        return false unless current_user

        current_user.can?(:access_duo_agentic_chat, project)
      end
    end
  end
end
