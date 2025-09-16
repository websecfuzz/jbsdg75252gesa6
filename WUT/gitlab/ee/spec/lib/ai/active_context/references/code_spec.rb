# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::References::Code, feature_category: :code_suggestions do
  let(:identifier) { 'hash1' }
  let(:unit_primitive) { described_class::UNIT_PRIMITIVE }
  let(:routing) { 1 }

  let_it_be(:collection) do
    create(
      :ai_active_context_collection,
      :code_embeddings_with_versions,
      include_ref_fields: false
    )
  end

  let(:reference) { described_class.new(collection_id: collection.id, routing: routing, args: identifier) }

  describe '#serialize' do
    it 'serializes correctly' do
      expect(reference.serialize).to eq("#{described_class}|#{collection.id}|#{routing}|#{identifier}")
    end
  end

  describe '#operation' do
    it 'is update' do
      expect(reference.operation).to eq(:update)
    end
  end

  describe '#jsons' do
    it 'contains the identifier and ref fields' do
      expect(reference.jsons).to eq([{ unique_identifier: identifier }])
    end
  end

  describe '.preprocessors' do
    it 'has preprocessing for getting content and generating embeddings' do
      expect(described_class.preprocessors.pluck(:name)).to eq([:get_content, :embeddings])
    end
  end

  describe '.preprocess_references' do
    let(:identifier_2) { 'hash2' }
    let(:reference_2) { described_class.new(collection_id: collection.id, routing: routing, args: identifier_2) }

    let(:refs) { [reference, reference_2] }

    let(:search_response) do
      [
        { 'id' => identifier, 'content' => 'content_1' },
        { 'id' => identifier_2, 'content' => 'content_2' }
      ]
    end

    let(:embedding_1) { [1, 2, 3] }
    let(:embedding_2) { [4, 5, 6] }

    let(:embedding_versions) { [{ model: 'text-embedding-005', field: 'embeddings_v1' }] }

    before do
      # mock the call to the vector store
      allow(::ActiveContext).to receive_message_chain(:adapter, :client, :search).and_return(search_response)
      # mock the call to embeddings generation which calls AIGW
      allow(Ai::ActiveContext::Embeddings::Code::VertexText).to receive(:generate_embeddings)
        .with(
          %w[content_1 content_2],
          model: 'text-embedding-005',
          unit_primitive: unit_primitive,
          user: nil,
          batch_size: 40
        ).and_return([embedding_1, embedding_2])

      allow(described_class).to receive(:fetch_content).and_call_original
      allow(described_class).to receive(:apply_embeddings).and_call_original
    end

    it 'calls `fetch_content` with the correct references' do
      expect(described_class).to receive(:apply_embeddings) do |args|
        expect(args[:refs]).to eq([reference, reference_2])

        { successful: args[:refs], failed: [] }
      end

      described_class.preprocess_references(refs)
    end

    it 'calls `apply_embeddings` with the correct arguments' do
      expect(described_class).to receive(:apply_embeddings) do |args|
        # references should have the updated content
        passed_refs = args[:refs]
        expect(passed_refs).to eq([reference, reference_2])
        expect(passed_refs.first.documents.pluck(:content)).to eq(['content_1'])
        expect(passed_refs.second.documents.pluck(:content)).to eq(['content_2'])

        { successful: passed_refs, failed: [] }
      end

      described_class.preprocess_references(refs)
    end

    it 'has no failed refs' do
      result = described_class.preprocess_references(refs)
      expect(result[:failed]).to be_empty
    end

    it 'sets the contents and embeddings for each successful ref' do
      result = described_class.preprocess_references(refs)
      successful_refs = result[:successful]

      expect(successful_refs).to eq([reference, reference_2])
      expect(successful_refs.first.jsons).to eq(
        [
          {
            content: 'content_1',
            unique_identifier: identifier,
            embeddings_v1: embedding_1
          }
        ]
      )
      expect(successful_refs.second.jsons).to eq(
        [
          {
            content: 'content_2',
            unique_identifier: identifier_2,
            embeddings_v1: embedding_2
          }
        ]
      )
    end

    context 'when some refs do not have corresponding content' do
      let(:search_response) do
        [
          { 'id' => identifier, 'content' => 'content_1' }
        ]
      end

      before do
        allow(Ai::ActiveContext::Embeddings::Code::VertexText).to receive(:generate_embeddings)
          .with(
            %w[content_1],
            model: 'text-embedding-005',
            unit_primitive: unit_primitive,
            user: nil,
            batch_size: 40
          ).and_return([embedding_1])
      end

      it 'puts the refs in the correct groups' do
        expect(::ActiveContext::Logger).to receive(:retryable_exception)

        results = described_class.preprocess_references(refs)
        successful_refs = results[:successful]
        failed_refs = results[:failed]

        expect(successful_refs).to eq([reference])
        expect(successful_refs.first.jsons).to eq(
          [
            {
              content: 'content_1',
              unique_identifier: identifier,
              embeddings_v1: embedding_1
            }
          ]
        )

        expect(failed_refs).to eq([reference_2])
        expect(failed_refs.first.jsons).to eq(
          [
            { unique_identifier: identifier_2 }
          ]
        )
      end
    end

    context 'when the embeddings versions are not set' do
      before do
        allow(reference).to receive(:embedding_versions).and_return([])
        allow(reference_2).to receive(:embedding_versions).and_return([])
      end

      it 'does not generate embeddings' do
        expect(Ai::ActiveContext::Embeddings::Code::VertexText).not_to receive(:generate_embeddings)

        result = described_class.preprocess_references(refs)
        successful_refs = result[:successful]
        failed_refs = result[:failed]

        expect(failed_refs).to be_empty

        expect(successful_refs).to eq([reference, reference_2])
        expect(successful_refs.first.jsons).to eq(
          [
            {
              content: 'content_1',
              unique_identifier: identifier
            }
          ]
        )
        expect(successful_refs.second.jsons).to eq(
          [
            {
              content: 'content_2',
              unique_identifier: identifier_2
            }
          ]
        )
      end
    end

    context 'when generate_embeddings raises an error' do
      before do
        allow(Ai::ActiveContext::Embeddings::Code::VertexText).to receive(
          :generate_embeddings).and_raise(StandardError, 'Failure')
      end

      it 'puts the refs in the correct groups' do
        expect(::ActiveContext::Logger).to receive(:retryable_exception)

        result = described_class.preprocess_references(refs)
        successful_refs = result[:successful]
        failed_refs = result[:failed]

        expect(successful_refs).to be_empty

        expect(failed_refs).to eq([reference, reference_2])
        expect(failed_refs.first.jsons).to eq(
          [
            {
              content: 'content_1',
              unique_identifier: identifier
            }
          ]
        )
        expect(failed_refs.second.jsons).to eq(
          [
            {
              content: 'content_2',
              unique_identifier: identifier_2
            }
          ]
        )
      end
    end
  end
end
