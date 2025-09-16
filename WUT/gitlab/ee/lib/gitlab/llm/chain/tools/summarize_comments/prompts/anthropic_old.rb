# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Tools
        module SummarizeComments
          module Prompts
            class AnthropicOld
              include Concerns::AnthropicPrompt

              TEMPERATURE = 0.1

              def self.prompt(variables)
                {
                  messages: Gitlab::Llm::Chain::Utils::Prompt.role_conversation(
                    Gitlab::Llm::Chain::Utils::Prompt.format_conversation([
                      ::Gitlab::Llm::Chain::Tools::SummarizeComments::ExecutorOld::USER_PROMPT,
                      Utils::Prompt.as_assistant("")
                    ], variables)
                  ),
                  system: Gitlab::Llm::Chain::Utils::Prompt.no_role_text(
                    [::Gitlab::Llm::Chain::Tools::SummarizeComments::ExecutorOld::SYSTEM_PROMPT], variables),
                  model: ::Gitlab::Llm::Anthropic::Client::CLAUDE_3_5_SONNET,
                  temperature: TEMPERATURE
                }
              end
            end
          end
        end
      end
    end
  end
end
