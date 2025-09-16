# frozen_string_literal: true

module Resolvers
  module Ai
    class UserAvailableFeaturesResolver < BaseResolver
      type [::GraphQL::Types::String], null: false

      def resolve
        return [] unless current_user
        return [] unless duo_chat_enabled?

        ::Ai::AdditionalContext::DUO_CHAT_CONTEXT_CATEGORIES.values
          .select { |category| category_enabled?(category) }
          .map { |category| "include_#{category}_context" }
          .select { |service_name| current_user.allowed_to_use?(:chat, service_name: service_name.to_sym) }
      end

      private

      def duo_chat_enabled?
        # ee/app/graphql/resolvers/ai/user_chat_access_resolver.rb we have the same pattern
        ::Gitlab::Llm::Chain::Utils::ChatAuthorizer.user(user: current_user).allowed?
      end

      def category_enabled?(category)
        already_enabled_context = %w[file snippet].freeze
        return true if already_enabled_context.include?(category)

        Feature.enabled?(:"duo_include_context_#{category}", current_user)
      end
    end
  end
end
