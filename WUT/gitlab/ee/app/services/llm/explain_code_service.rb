# frozen_string_literal: true

module Llm
  class ExplainCodeService < BaseService
    TOTAL_MODEL_TOKEN_LIMIT = 4096
    MAX_RESPONSE_TOKENS = 300

    # Let's use a low multiplier until we're able to correctly calculate the number of tokens
    INPUT_CONTENT_LIMIT = (TOTAL_MODEL_TOKEN_LIMIT - MAX_RESPONSE_TOKENS) * 4

    def valid?
      super &&
        resource.licensed_feature_available?(:explain_code) &&
        Gitlab::Llm::StageCheck.available?(resource, :explain_code)
    end

    private

    def perform
      return error('The messages are too big') if messages_are_too_big?

      schedule_completion_worker
    end

    def messages_are_too_big?
      options[:messages].sum { |message| message[:content].size } > INPUT_CONTENT_LIMIT
    end

    def ai_action
      :explain_code
    end
  end
end
