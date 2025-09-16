# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Concerns::AiDependent, feature_category: :duo_chat do
  let_it_be(:user) { create(:user) }

  let(:options) { { suggestions: "", input: "" } }
  let(:ai_request) { ::Gitlab::Llm::Chain::Requests::AiGateway.new(user) }
  let(:context) do
    ::Gitlab::Llm::Chain::GitlabContext.new(
      current_user: user,
      container: double,
      resource: double,
      ai_request: ai_request
    )
  end

  let(:logger) { instance_double('Gitlab::Llm::Logger') }

  describe '#prompt' do
    it "returns prompt" do
      tool = ::Gitlab::Llm::Chain::Tools::IssueReader::Executor.new(context: context, options: options)

      expect(tool.class::PROVIDER_PROMPT_CLASSES[:anthropic]).to receive(:prompt).and_call_original

      tool.prompt
    end

    context "when calling summarize comments tool" do
      let_it_be(:project) { create(:project) }
      let_it_be(:issue) { create(:issue, project: project) }
      let_it_be(:note) do
        create(:note_on_issue, noteable: issue, project: project, note: "Please correct this small nit")
      end

      let(:context) do
        Gitlab::Llm::Chain::GitlabContext.new(
          current_user: user, container: double, resource: issue, ai_request: ai_request
        )
      end

      let(:tool) do
        ::Gitlab::Llm::Chain::Tools::SummarizeComments::Executor.new(
          context: context,
          options: {
            input: 'Summarize issue comments.',
            notes_content: "<comment>#{note.note}</comment>"
          }
        )
      end

      it "returns prompt" do
        expect(tool.class::PROVIDER_PROMPT_CLASSES[:anthropic]).to receive(:prompt).and_call_original

        tool.prompt
      end
    end

    context 'when there are no provider prompt classes' do
      let(:dummy_tool_class) do
        Class.new(::Gitlab::Llm::Chain::Tools::Tool) do
          include ::Gitlab::Llm::Chain::Concerns::AiDependent

          def provider_prompt_class
            nil
          end
        end
      end

      it 'raises error' do
        tool = dummy_tool_class.new(context: context, options: {})

        expect { tool.prompt }.to raise_error(NoMethodError)
      end
    end
  end

  describe '#request' do
    let(:tool) { ::Gitlab::Llm::Chain::Tools::IssueReader::Executor.new(context: context, options: options) }
    let(:prompt_options) do
      tool.prompt.deep_merge({ options: { inputs: options, use_ai_gateway_agent_prompt: true,
                                          prompt_version: '^1.0.0' } })
    end

    before do
      allow(Gitlab::Llm::Logger).to receive(:build).and_return(logger)
      allow(logger).to receive(:conditional_info)
    end

    it 'passes prompt and unit primitive to the ai_client' do
      expect(ai_request).to receive(:request).with(prompt_options, unit_primitive: 'issue_reader')

      tool.request
    end

    it 'passes blocks forward to the ai_client' do
      b = proc { "something" }

      expect(ai_request).to receive(:request).with(prompt_options, unit_primitive: 'issue_reader', &b)

      tool.request(&b)
    end

    it 'passes the customized url' do
      tool = Class.new(::Gitlab::Llm::Chain::Tools::Tool) do
        include ::Gitlab::Llm::Chain::Concerns::AiDependent

        def prompt
          { prompt: [] }
        end

        def unit_primitive
          :test
        end

        def use_ai_gateway_agent_prompt?
          true
        end

        def prompt_options
          { field: :test_field }
        end
      end.new(context: context, options: {})

      expect(ai_request).to receive(:request).with(
        tool.prompt.merge(
          options: {
            inputs: {
              field: :test_field
            },
            use_ai_gateway_agent_prompt: true,
            prompt_version: '^1.0.0'
          }
        ),
        unit_primitive: :test
      )

      tool.request
    end

    it 'logs the request' do
      expected_prompt = tool.prompt[:prompt]

      tool.request

      expect(logger).to have_received(:conditional_info).with(context.current_user, a_hash_including(
        message: "Content of the prompt from chat request", event_name: "prompt_content", ai_component: "duo_chat",
        prompt: expected_prompt))
    end
  end
end
