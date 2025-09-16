# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Tools::TroubleshootJob::Prompts::Anthropic, feature_category: :duo_chat do
  let(:user) { create(:user) }

  describe '.prompt' do
    it 'returns prompt', :aggregate_failures do
      result = described_class.prompt(
        input: 'question',
        language_info: 'The repo is written in Ruby.',
        selected_text: 'BUILD LOG'
      )
      prompt = result[:prompt]

      expected_system_prompt = <<~PROMPT
        You are a Software engineer's or DevOps engineer's Assistant.
        You can explain the root cause of a GitLab CI verification job code failure from the job log.
        The repo is written in Ruby.
      PROMPT

      expected_user_prompt = <<~PROMPT.chomp
      You are tasked with analyzing a job log to determine why a job failed. Your goal is to explain the root cause of the failure in a way that any Software engineer could understand. Follow these steps carefully:

      1. Review the tail end of the job log provided within the <log> tags:

      <log>
        BUILD LOG
      </log>

      2. Analyze the job log carefully, focus on errors and failures. Ignore warning, and deprecation warnings, as they are often not relevant to this failure.

      3. Think through the analysis step by step. Consider the sequence of events in the log, the specific error messages, and how they relate to each other. Do not suggest fixing the test unless it's clearly the source of the problem.

      4. In your response, use the following structure:
        a. Start with an H4 heading "Root cause of failure"
        b. Explain the root cause of the failure
        c. Use an H4 heading "Example Fix"
        d. Provide an example fix or suggestions for resolution

      5. When explaining the root cause:
        - Focus on actual errors, not warnings or deprecation messages
        - Describe the chain of events leading to the failure
        - Identify the specific line or component that triggered the failure
        - Explain why this caused the job to fail

      6. When providing an example fix:
        - If you can determine a specific code change, describe it in detail
        - If you're unsure about the exact fix, provide general suggestions or options
        - Emphasize that the actual project context may vary and your analysis is based solely on the provided job logs

      7. To prevent hallucination:
        - Only refer to information explicitly present in the log
        - If you're unsure about any aspect, clearly state your uncertainty
        - Do not invent or assume details not present in the log
        - If you cannot determine the root cause from the given information, state this clearly and explain why

      Remember, your analysis should be based solely on the information provided in the job log. Do not make assumptions about the broader system or codebase unless explicitly evidenced in the log. Begin your response with the "Root cause of failure" heading, skipping any preamble.
      PROMPT

      expected_prompt = [
        {
          role: :system, content: expected_system_prompt
        },
        {
          role: :user, content: expected_user_prompt
        }
      ]
      expect(prompt).to eq(expected_prompt)
    end
  end
end
