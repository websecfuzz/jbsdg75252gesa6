# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::VertexAi::Embeddings::Text, feature_category: :ai_abstraction_layer do
  let_it_be(:user) { create(:user) }
  let(:text) { 'example text' }
  let(:type) { 'issue' }
  let(:embeddings) { [1, 2, 3] }
  let(:success) { true }
  let(:context) { { action: 'embedding' } }
  let(:primitive) { 'documentation_search' }
  let(:model) { 'embedding-model-v1' }

  subject(:execute) do
    described_class.new(text, user: user, tracking_context: context, unit_primitive: primitive).execute
  end

  describe '#execute' do
    let(:example_response) do
      {
        "predictions" => [
          {
            "embeddings" => {
              "values" => embeddings,
              "statistics" => {
                "token_count" => 3
              },
              "metadata" => {
                "billableCharacterCount" => 4
              }
            }
          }
        ]
      }.to_json
    end

    before do
      allow_next_instance_of(Gitlab::Llm::VertexAi::Client) do |client|
        allow(client).to receive(:text_embeddings).and_return(example_response)
      end

      allow(example_response).to receive_messages(success?: success, bad_request?: false)
    end

    it 'passes nil as the model to the client' do
      expect_next_instance_of(Gitlab::Llm::VertexAi::Client) do |client|
        expect(client).to receive(:text_embeddings)
          .with(content: Array.wrap(text), model: nil).and_return(example_response)
      end

      execute
    end

    context 'when using a custom model' do
      it 'passes the model to the client' do
        expect_next_instance_of(Gitlab::Llm::VertexAi::Client) do |client|
          expect(client).to receive(:text_embeddings)
            .with(content: Array.wrap(text), model: model).and_return(example_response)
        end

        described_class.new(text, user: user, tracking_context: context, unit_primitive: primitive, model: model)
          .execute
      end
    end

    context 'when the text model returns a successful response' do
      it 'returns the embeddings from the response' do
        expect(::Gitlab::Llm::VertexAi::ResponseModifiers::Embeddings)
          .to receive(:new)
          .with(example_response)
          .and_call_original

        expect(execute).to eq(embeddings)
      end
    end

    context 'when requesting more than the limit' do
      let(:text) { Array.new(limit + 1) { 'text' } }
      let(:limit) { 5 }

      before do
        stub_const("#{described_class}::BULK_LIMIT", limit)
      end

      it 'raises an error' do
        expect { execute }.to raise_error(StandardError, /Cannot generate embeddings for more than 5 texts at once/)
      end
    end

    context 'when the API returns an error response' do
      let(:example_response) { { error: { message: 'error' } }.to_json }
      let(:success) { false }

      it 'raises an error' do
        expect(::Gitlab::Llm::VertexAi::ResponseModifiers::Embeddings)
          .to receive(:new)
          .with(example_response)
          .and_call_original

        expect { execute }.to raise_error(StandardError, /error/)
      end

      context 'when error is about exceeded token limits' do
        let(:example_response) { { error: { message: error_message } } }
        let(:error_message) do
          "Unable to submit request " \
            "because the input token count is 20001 but the model supports up to 20000. " \
            "Reduce the input token count and try again."
        end

        before do
          allow(example_response).to receive(:bad_request?).and_return(true)
        end

        it 'raises a TokenLimitExceeded error' do
          expect { execute }.to raise_error(described_class::TokenLimitExceededError, /#{error_message}/)
        end
      end
    end

    context 'when the API returns an unsuccessful response' do
      let(:success) { false }

      it 'raises an error' do
        expect(::Gitlab::Llm::VertexAi::ResponseModifiers::Embeddings)
          .to receive(:new)
          .with(example_response)
          .and_call_original

        expect { execute }.to raise_error(StandardError, /Could not generate embedding/)
      end
    end

    context 'when the API returns an empty response' do
      let(:example_response) { { 'predictions' => [] } }

      it 'raises an error' do
        expect(::Gitlab::Llm::VertexAi::ResponseModifiers::Embeddings)
          .to receive(:new)
          .with(example_response)
          .and_call_original

        expect { execute }.to raise_error(StandardError, /Could not generate embedding/)
      end
    end

    context 'when an error is raised' do
      let(:error) { StandardError.new('Error') }

      before do
        allow_next_instance_of(Gitlab::Llm::VertexAi::Client) do |client|
          allow(client).to receive(:text_embeddings).and_raise(error)
        end
      end

      it 'raises an error' do
        expect { execute }.to raise_error(StandardError)
      end
    end
  end
end
