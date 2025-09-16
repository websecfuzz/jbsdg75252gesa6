# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable Style/StringConcatenation -- To distinguish new line as the delimiter and new line as tokens
RSpec.describe Gitlab::Duo::Chat::StepExecutor, feature_category: :duo_chat do
  let(:user) { create(:user) }
  let(:agent) { described_class.new(user) }

  describe '#step' do
    let(:params) do
      {
        prompt: "Hello",
        options: { chat_history: "" }
      }
    end

    let(:response) { instance_double(HTTParty::Response, headers: {}) }

    before do
      allow(response).to receive(:success?).and_return(true)
      allow(response).to receive(:code).and_return(200)

      allow(Gitlab::AiGateway).to receive(:headers).and_return({})
    end

    context 'when final answer delta events' do
      before do
        allow(Gitlab::HTTP).to receive(:post).and_yield(
          '{"type": "final_answer_delta", "data": {"text": "Hi"}}' + described_class::EVENT_DELIMITER
        ).and_yield(
          '{"type": "final_answer_delta", "data": {"text": "I am good"}}' + described_class::EVENT_DELIMITER
        ).and_return(response)
      end

      it 'streams events' do
        events = agent.step(params)

        expect(events.count).to eq(2)
        expect(events.first).to be_instance_of(Gitlab::Duo::Chat::AgentEvents::FinalAnswerDelta)
        expect(events.first.text).to eq('Hi')
        expect(events.last).to be_instance_of(Gitlab::Duo::Chat::AgentEvents::FinalAnswerDelta)
        expect(events.last.text).to eq('I am good')
      end
    end

    context 'when tool action event' do
      before do
        allow(Gitlab::HTTP).to receive(:post).and_yield(
          '{"type": "action", "data": {"thought": "I think I need to use issue_reader", ' \
            '"tool": "issue_reader", "tool_input": "#123"}}' + described_class::EVENT_DELIMITER
        ).and_return(response)
      end

      it 'streams events' do
        events = agent.step(params)

        expect(events.count).to eq(1)
        expect(events.first).to be_instance_of(Gitlab::Duo::Chat::AgentEvents::Action)
        expect(events.first.thought).to eq('I think I need to use issue_reader')
        expect(events.first.tool).to eq('issue_reader')
        expect(events.first.tool_input).to eq('#123')
      end

      it 'step multiple times' do
        agent.step(params)

        expect(agent.agent_steps).to eq([
          {
            action:
              { thought: 'I think I need to use issue_reader',
                tool: 'issue_reader',
                tool_input: '#123' }
          }
        ])

        agent.update_observation('Issue #123 is about deep learning models.')

        expect(agent.agent_steps).to eq([
          {
            action:
              { thought: 'I think I need to use issue_reader',
                tool: 'issue_reader',
                tool_input: '#123' },
            observation: 'Issue #123 is about deep learning models.'
          }
        ])

        agent.step(params)
      end
    end

    context 'when unknown event' do
      before do
        allow(Gitlab::HTTP).to receive(:post).and_yield(
          '{"type": "unknown", "data": {"text": "indeterministic response"}}' + described_class::EVENT_DELIMITER
        ).and_return(response)
      end

      it 'streams events' do
        events = agent.step(params)

        expect(events.count).to eq(1)
        expect(events.first).to be_instance_of(Gitlab::Duo::Chat::AgentEvents::Unknown)
        expect(events.first.text).to eq('indeterministic response')
      end
    end

    context 'when data size of unknown event exceeds buffer size of Gitlab::HTTP' do
      before do
        allow(Gitlab::HTTP).to receive(:post).and_yield(
          '{"type": "unknown",'
        ).and_yield(
          '"data": {"text": "indeterministic response"}}' + described_class::EVENT_DELIMITER
        ).and_return(response)
      end

      it 'streams events' do
        events = agent.step(params)

        expect(events.count).to eq(1)
        expect(events.first).to be_instance_of(Gitlab::Duo::Chat::AgentEvents::Unknown)
        expect(events.first.text).to eq('indeterministic response')
      end
    end

    context 'when multiple events exist in a single chunk' do
      before do
        allow(Gitlab::HTTP).to receive(:post).and_yield(
          <<~CHUNK
            {"type": "final_answer_delta", "data": {"text": "Hi"}}
            {"type": "final_answer_delta", "data": {"text": "I am good"}}

          CHUNK
        ).and_return(response)
      end

      it 'streams events' do
        events = agent.step(params)

        expect(events.count).to eq(2)
        expect(events.first).to be_instance_of(Gitlab::Duo::Chat::AgentEvents::FinalAnswerDelta)
        expect(events.first.text).to eq('Hi')
        expect(events.last).to be_instance_of(Gitlab::Duo::Chat::AgentEvents::FinalAnswerDelta)
        expect(events.last.text).to eq('I am good')
      end
    end

    context 'when multiple events are spread in multiple chunks' do
      before do
        allow(Gitlab::HTTP).to receive(:post).and_yield(
          '{"type": "final_answer_delta", "data": {"text": "Hi"}}' + described_class::EVENT_DELIMITER +
            '{"type": "final_answer_delta"'
        ).and_yield(
          ', "data": {"text": "I am good"}}' + described_class::EVENT_DELIMITER
        ).and_return(response)
      end

      it 'streams events' do
        events = agent.step(params)

        expect(events.count).to eq(2)
        expect(events.first).to be_instance_of(Gitlab::Duo::Chat::AgentEvents::FinalAnswerDelta)
        expect(events.first.text).to eq('Hi')
        expect(events.last).to be_instance_of(Gitlab::Duo::Chat::AgentEvents::FinalAnswerDelta)
        expect(events.last.text).to eq('I am good')
      end
    end

    context 'when new lines included in final answer delta data' do
      before do
        allow(Gitlab::HTTP).to receive(:post).and_yield(
          '{"type": "final_answer_delta", "data": {"text": "\n\n```toml"}}' + described_class::EVENT_DELIMITER
        ).and_return(response)
      end

      it 'streams events' do
        events = agent.step(params)

        expect(events.count).to eq(1)
        expect(events.first).to be_instance_of(Gitlab::Duo::Chat::AgentEvents::FinalAnswerDelta)
        expect(events.first.text).to eq("\n\n```toml")
      end
    end

    context 'when got forbidden response' do
      before do
        allow(response).to receive(:success?).and_return(false)
        allow(response).to receive(:forbidden?).and_return(true)
        allow(Gitlab::HTTP).to receive(:post).and_return(response)
      end

      it 'raises error' do
        expect { agent.step(params) }.to raise_error(Gitlab::AiGateway::ForbiddenError)
      end
    end

    context 'when got 4xx response' do
      before do
        allow(response).to receive(:success?).and_return(false)
        allow(response).to receive(:forbidden?).and_return(false)
        allow(response).to receive(:code).and_return(400)
        allow(Gitlab::HTTP).to receive(:post).and_return(response)
      end

      it 'raises error' do
        expect { agent.step(params) }.to raise_error(Gitlab::AiGateway::ClientError)
      end
    end

    context 'when got 5xx response' do
      before do
        allow(response).to receive(:success?).and_return(false)
        allow(response).to receive(:forbidden?).and_return(false)
        allow(response).to receive(:code).and_return(500)
        allow(Gitlab::HTTP).to receive(:post).and_return(response)
      end

      it 'raises error' do
        expect { agent.step(params) }.to raise_error(Gitlab::AiGateway::ServerError)
      end
    end

    context 'when the other error case' do
      before do
        allow(response).to receive(:success?).and_return(false)
        allow(response).to receive(:forbidden?).and_return(false)
        allow(response).to receive(:code).and_return(0)
        allow(Gitlab::HTTP).to receive(:post).and_return(response)
      end

      it 'raises error' do
        expect { agent.step(params) }.to raise_error(described_class::ConnectionError)
      end
    end
  end
end
# rubocop:enable Style/StringConcatenation
