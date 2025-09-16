# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Anthropic::Completions::DescriptionComposer, feature_category: :code_review_workflow do
  let(:prompt_class) { Gitlab::Llm::Anthropic::Templates::DescriptionComposer }
  let(:options) { {} }
  let(:response_modifier) { double }
  let(:response_service) { double }
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let(:params) do
    [user, project, response_modifier, { options: { request_id: 'uuid', ai_action: :description_composer } }]
  end

  let(:prompt_message) do
    build(:ai_message, :description_composer, user: user, resource: project, request_id: 'uuid')
  end

  subject(:generate) { described_class.new(prompt_message, prompt_class, options) }

  describe '#execute' do
    context 'when the text model returns an unsuccessful response' do
      before do
        allow_next_instance_of(Gitlab::Llm::Anthropic::Client) do |client|
          allow(client).to receive(:messages_complete).and_return(
            { error: 'Error' }.to_json
          )
        end
      end

      it 'publishes the error to the graphql subscription' do
        errors = { error: 'Error' }
        expect(::Gitlab::Llm::Anthropic::ResponseModifiers::DescriptionComposer).to receive(:new)
          .with(errors.to_json)
          .and_return(response_modifier)
        expect(::Gitlab::Llm::GraphqlSubscriptionResponseService).to receive(:new).with(*params).and_return(
          response_service
        )
        expect(response_service).to receive(:execute)

        generate.execute
      end
    end

    context 'when the text model returns a successful response' do
      let(:example_answer) { "AI generated commit message" }
      let(:example_response) { { content: [{ text: example_answer }] } }

      before do
        allow_next_instance_of(Gitlab::Llm::Anthropic::Client) do |client|
          allow(client).to receive(:messages_complete).and_return(example_response&.to_json)
        end
      end

      it 'publishes the content from the AI response' do
        expect(::Gitlab::Llm::Anthropic::ResponseModifiers::DescriptionComposer).to receive(:new)
          .with(example_response.to_json)
          .and_return(response_modifier)
        expect(::Gitlab::Llm::GraphqlSubscriptionResponseService).to receive(:new).with(*params).and_return(
          response_service
        )
        expect(response_service).to receive(:execute)

        generate.execute
      end

      context 'when response is nil' do
        let(:example_response) { nil }

        it 'publishes the content from the AI response' do
          expect(::Gitlab::Llm::Anthropic::ResponseModifiers::DescriptionComposer)
            .to receive(:new)
            .with(nil)
            .and_return(response_modifier)

          expect(::Gitlab::Llm::GraphqlSubscriptionResponseService)
            .to receive(:new)
            .with(*params)
            .and_return(response_service)

          expect(response_service).to receive(:execute)

          generate.execute
        end
      end

      context 'when an unexpected error is raised' do
        let(:error) { StandardError.new("Error") }

        before do
          allow_next_instance_of(Gitlab::Llm::Anthropic::Client) do |client|
            allow(client).to receive(:messages_complete).and_raise(error)
          end
          allow(Gitlab::ErrorTracking).to receive(:track_exception)
        end

        it 'records the error' do
          generate.execute
          expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(error)
        end

        it 'publishes a generic error to the graphql subscription' do
          errors = { error: { message: 'An unexpected error has occurred.' } }
          expect(::Gitlab::Llm::Anthropic::ResponseModifiers::DescriptionComposer).to receive(:new)
            .with(errors.to_json)
            .and_return(response_modifier)
          expect(::Gitlab::Llm::GraphqlSubscriptionResponseService).to receive(:new).with(*params).and_return(
            response_service
          )
          expect(response_service).to receive(:execute)

          generate.execute
        end
      end
    end
  end
end
