# frozen_string_literal: true

module Types
  module Ai
    class ChatInputType < BaseMethodInputType
      graphql_name 'AiChatInput'

      argument :resource_id,
        ::Types::GlobalIDType[::Ai::Model],
        required: false,
        description: "Global ID of the resource to mutate."

      argument :namespace_id,
        ::Types::GlobalIDType[::Namespace],
        required: false,
        description: "Global ID of the namespace the user is acting on."

      argument :agent_version_id,
        ::Types::GlobalIDType[::Ai::AgentVersion],
        required: false,
        description: "Global ID of the agent version to answer the chat."

      argument :content, GraphQL::Types::String,
        required: true,
        validates: { allow_blank: false },
        description: 'Content of the message.'

      argument :current_file, ::Types::Ai::CurrentFileInputType,
        required: false,
        description: 'Information about currently selected text which can be passed for additional context.'

      argument :additional_context, [::Types::Ai::AdditionalContextInputType],
        required: false,
        description: 'Additional context to be passed for the chat.'
    end
  end
end
