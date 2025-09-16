# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::AiGateway::Completions::CategorizeQuestion, feature_category: :duo_chat do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:user) { create(:user) }
  let_it_be(:ai_conversation_thread) { create(:ai_conversation_thread, user: user) }
  let_it_be(:ai_conversation_message) { create(:ai_conversation_message, thread: ai_conversation_thread) }
  let_it_be(:question) { 'What is the pipeline?' }
  let(:chat_message) do
    message = build(:ai_chat_message, content: question, id: ai_conversation_message.message_xid)
    message.active_record = ai_conversation_message
    message.thread = ai_conversation_thread
    message
  end

  let(:template_class) { ::Gitlab::Llm::Templates::CategorizeQuestion }
  let(:ai_client) { instance_double(Gitlab::Llm::AiGateway::Client) }
  let(:ai_response) { instance_double(HTTParty::Response, body: llm_analysis_response.to_json, success?: true) }
  let(:uuid) { SecureRandom.uuid }
  let(:tracking_context) { { action: :categorize_question, request_id: uuid } }
  let(:messages) { [chat_message] }
  let(:message_id) { chat_message.id }
  let(:ai_options) { { question: chat_message.content, message_id: message_id } }
  let(:prompt_message) { build(:ai_message, :categorize_question, user: user, request_id: uuid) }
  let(:llm_analysis_response) do
    {
      detailed_category: "Summarize Issue",
      category: 'Summarize something',
      labels: %w[contains_code is_related_to_gitlab],
      language: 'en',
      extra: 'foo'
    }.to_json
  end

  before do
    allow_next_instance_of(::Gitlab::Llm::ChatStorage, user, nil, chat_message.thread) do |storage|
      allow(storage).to receive(:messages_up_to).with(chat_message.id).and_return(messages)
    end
  end

  def expect_client
    expect(Gitlab::Llm::AiGateway::Client).to receive(:new).with(
      user,
      service_name: :duo_chat,
      tracking_context: tracking_context
    ).and_return(ai_client)
    expect(ai_client).to receive(:complete_prompt).with(
      base_url: Gitlab::AiGateway.url,
      prompt_name: :categorize_question,
      inputs: inputs,
      model_metadata: nil,
      prompt_version: "^1.0.0"
    ).and_return(ai_response)

    expect(::Gitlab::Llm::GraphqlSubscriptionResponseService).to receive(:new).and_call_original
  end

  describe "#execute" do
    let(:inputs) do
      {
        previous_answer: nil,
        question: question
      }
    end

    subject(:execute) { described_class.new(prompt_message, template_class, ai_options).execute }

    it 'executes a completion request and calls the response chains' do
      expect_client
      expect(execute[:ai_message].errors).to be_empty

      expect_snowplow_event(
        category: described_class.to_s,
        action: 'ai_question_category',
        requestId: uuid,
        user: user,
        context: [{
          schema: described_class::SCHEMA_URL,
          data: {
            'detailed_category' => "Summarize Issue",
            'category' => "Summarize something",
            'contains_code' => true,
            'is_related_to_gitlab' => true,
            'number_of_conversations' => 1,
            'number_of_questions_in_conversation' => 1,
            'length_of_questions_in_conversation' => 21,
            'length_of_questions' => 21,
            'first_question_after_reset' => false,
            'time_since_beginning_of_conversation' => 0,
            'language' => "en"
          }
        }]
      )
    end

    context 'when previous answer is present' do
      let(:previous_answer) { build(:ai_chat_message, :assistant, content: '<answer>') }
      let(:messages) { [previous_answer, chat_message] }

      let(:inputs) do
        {
          previous_answer: previous_answer.content,
          question: question
        }
      end

      it 'includes previous answer as input' do
        expect_client
        expect(execute[:ai_message].errors).to be_empty
      end
    end

    context 'when no attributes are returned' do
      let(:llm_analysis_response) do
        {}.to_json
      end

      it 'returns error message' do
        expect_client
        expect(execute[:ai_message].errors).to include('Event not tracked')
      end
    end

    context 'with invalid attributes' do
      let(:llm_analysis_response) do
        {
          detailed_category: "Foo Bar",
          category: 'Foo Bar',
          labels: %w[contains_code is_related_to_gitlab foo_bar],
          language: 'FooBar',
          extra: 'foo'
        }.to_json
      end

      it 'tracks event, replacing invalid attributes' do
        expect_client
        expect(execute[:ai_message].errors).to be_empty

        expect_snowplow_event(
          category: described_class.to_s,
          action: 'ai_question_category',
          requestId: uuid,
          user: user,
          context: [{
            schema: described_class::SCHEMA_URL,
            data: {
              'detailed_category' => "[Invalid]",
              'category' => "[Invalid]",
              'contains_code' => true,
              'is_related_to_gitlab' => true,
              'number_of_conversations' => 1,
              'number_of_questions_in_conversation' => 1,
              'length_of_questions_in_conversation' => 21,
              'length_of_questions' => 21,
              'first_question_after_reset' => false,
              'time_since_beginning_of_conversation' => 0,
              'language' => "[Invalid]"
            }
          }]
        )
      end
    end

    context 'when message_id no longer exists' do
      let(:message_id) { nil }

      it 'raises error' do
        expect(Gitlab::Llm::AiGateway::Client).not_to receive(:new)
        expect(execute).to be_nil
      end
    end
  end
end
