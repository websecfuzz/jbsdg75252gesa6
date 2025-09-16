# frozen_string_literal: true

RSpec::Matchers.define :match_llm_tools do |expected_tools|
  match do |context|
    @tools = context.tools_used.map { |tool| tool::NAME }
    expected_tools == @tools
  end

  failure_message do
    <<~STR
      expected tools: #{tools}
                 got: #{@tools}
    STR
  end
end
