# frozen_string_literal: true

module Resolvers
  module Ai
    class UserCodeSuggestionsContextsResolver < BaseResolver
      type [::GraphQL::Types::String], null: false

      def resolve
        return [] unless current_user
        return [] unless code_suggestions_enabled?

        code_suggestions_contexts.select do |context_key|
          additional_context_enabled?(context_key)
        end.map(&:to_s)
      end

      private

      def code_suggestions_contexts
        ::Ai::AdditionalContext::CODE_SUGGESTIONS_CONTEXT_CATEGORIES
      end

      def additional_context_enabled?(context_key)
        case context_key
        when :open_tabs
          open_tabs_enabled?
        when :repository_xray
          repository_xray_enabled?
        when :imports
          imports_enabled?
        end
      end

      def open_tabs_enabled?
        # On the GitLab Language Server (client), open_tabs context is checked against
        # the FFs `advanced_context_resolver` and `code_suggestions_context`.
        # These Feature Flags are not specific to Open Tabs.
        # `advanced_context_resolver` was introduced solely for the Language Server
        #   to check whether it should gather Code Suggestions additional contexts
        #   (MR: https://gitlab.com/gitlab-org/gitlab/-/merge_requests/154935)
        # `code_suggestions_context` was introduced for the `/code_suggestions/completions` API
        #   to check whether it should accept a `context` param
        #   (MR: https://gitlab.com/gitlab-org/gitlab/-/merge_requests/153264)
        # The Language Server always checks these 2 feature flags
        #   before it gathers additional context and send that in the Code Completion request.
        # The open_tabs context itself does not have its own Feature Flag,
        #   and in effect will always be true from the Rails (server) perspective
        #   as long as the user has access to code suggestions.
        true
      end

      def repository_xray_enabled?
        # The repository_xray additional context is enabled as long as
        #   the user has access to code suggestions.
        true
      end

      def imports_enabled?
        # The imports additional context is enabled as long as
        #   the user has access to code suggestions.
        true
      end

      def code_suggestions_enabled?
        Feature.enabled?(:ai_duo_code_suggestions_switch, type: :ops) && # rubocop: disable Gitlab/FeatureFlagWithoutActor -- this long-term ops FF never had an actor
          current_user.can?(:access_code_suggestions)
      end
    end
  end
end
