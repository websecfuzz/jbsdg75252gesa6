# frozen_string_literal: true

module Gitlab
  module Llm
    module VertexAi
      module ModelConfigurations
        class Code < Base
          NAME = ::Gitlab::Llm::Concerns::AvailableModels::VERTEX_MODEL_CODE
          MAX_OUTPUT_TOKENS = 2048

          def payload(content)
            {
              instances: [
                {
                  prefix: content
                }
              ],
              parameters: Configuration.payload_parameters(maxOutputTokens: MAX_OUTPUT_TOKENS)
            }
          end

          def as_json(opts = nil)
            super.merge(Configuration.payload_parameters(maxOutputTokens: MAX_OUTPUT_TOKENS))
          end
        end
      end
    end
  end
end
