# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Embeddings::Code::VertexText, feature_category: :code_suggestions do
  describe '.generate_embeddings' do
    subject(:generate_embeddings) do
      described_class.generate_embeddings(
        contents,
        unit_primitive: unit_primitive,
        model: model,
        user: user
      )
    end

    let(:llm_class) { Gitlab::Llm::VertexAi::Embeddings::Text }

    let(:contents) { %w[content-1 content-2 content-3 content-4 content-5] }
    let(:unit_primitive) { 'embeddings_generation' }
    let(:model) { 'test-embedding-model' }
    let(:user) { instance_double(User) }

    let(:embeddings) do
      [
        [1, 1],
        [2, 2],
        [3, 3],
        [4, 4],
        [5, 5]
      ]
    end

    let(:embeddings_model) { instance_double(llm_class, execute: embeddings) }

    before do
      allow(llm_class).to receive(:new).and_return(embeddings_model)
    end

    it 'initializes the correct model class with the expected parameters' do
      expect(llm_class).to receive(:new).with(
        contents,
        user: user,
        tracking_context: { action: 'embedding' },
        unit_primitive: unit_primitive,
        model: model
      )

      expect(embeddings_model).to receive(:execute).and_return(embeddings)

      expect(generate_embeddings).to eq embeddings
    end

    describe 'handling token limits exceeded errors' do
      before do
        allow(llm_class).to receive(:new) do |arg_contents|
          if arg_contents.length >= 3
            embeddings_model_with_error
          elsif arg_contents == contents_1_2
            embeddings_model_for_content_1_2
          elsif arg_contents == contents_3
            embeddings_model_for_content_3
          elsif arg_contents == contents_4_5
            embeddings_model_for_content_4_5
          end
        end
      end

      let(:token_limits_exceeded_error_class) { llm_class::TokenLimitExceededError }

      let(:embeddings_model_with_error) do
        instance_double(llm_class).tap do |llm_model|
          allow(llm_model).to receive(:execute).and_raise(token_limits_exceeded_error_class)
        end
      end

      let(:embeddings_model_for_content_1_2) do
        instance_double(llm_class, execute: [[1, 1], [2, 2]])
      end

      let(:embeddings_model_for_content_3) do
        instance_double(llm_class, execute: [[3, 3]])
      end

      let(:embeddings_model_for_content_4_5) do
        instance_double(llm_class, execute: [[4, 4], [5, 5]])
      end

      let(:contents_batch_size_5) { contents }
      let(:contents_batch_size_3) { %w[content-1 content-2 content-3] }
      let(:contents_1_2) { %w[content-1 content-2] }
      let(:contents_3) { ['content-3'] }
      let(:contents_4_5) { %w[content-4 content-5] }

      it 'recursively splits the batch size and eventually succeeds' do
        # in the `before` setup, we made sure that embeddings generation throws an error
        # if the size of the `contents` input is 3 or greater

        # 1 - attempt to generate embeddings for the entire `contents`
        #   %w[content-1 content-2 content-3 content-4 content-5]
        #   with batch_size = 5, this throws an error
        expect(llm_class).to receive(:new).with(contents_batch_size_5, anything).ordered

        # 2 - the batch is split in 2, and attempt to generate embeddings for the first half
        #   %w[content-1 content-2 content-3]
        #   with batch_size = 3, this throws an error
        expect(llm_class).to receive(:new).with(contents_batch_size_3, anything).ordered

        # 3 - split the first half batch from step 2 even further, the second batch remains as-is
        #   %w[content-1 content-2] - 1st split of the 1st half
        #   %w[content-3]           - 2nd split of the 1st half
        #   %w[content-4 content-5] - no split for the 2nd half of the original batch,
        #                             because there are only 2 inputs
        expect(llm_class).to receive(:new).with(contents_1_2, anything).ordered
        expect(llm_class).to receive(:new).with(contents_3, anything).ordered
        expect(llm_class).to receive(:new).with(contents_4_5, anything).ordered

        # after all the recursive batch splitting,
        # we still expect the call to `generate_embeddings` to
        # return the embeddings for *all* the contents of the original batch
        expect(generate_embeddings).to eq embeddings
      end

      context 'when running into token limits exceeded for a single input' do
        let(:embeddings_model_for_content_3) do
          instance_double(llm_class).tap do |llm_model|
            allow(llm_model).to receive(:execute).and_raise(token_limits_exceeded_error_class, "some error")
          end
        end

        it 'recursively splits the batch size but eventually fails' do
          # it tries to recursively split the batch until it gets to
          # the single-input batch for `contents_3` which raises an error
          expect(llm_class).to receive(:new).with(contents_batch_size_5, anything).ordered
          expect(llm_class).to receive(:new).with(contents_batch_size_3, anything).ordered
          expect(llm_class).to receive(:new).with(contents_1_2, anything).ordered
          expect(llm_class).to receive(:new).with(contents_3, anything).ordered

          # it no longer tries to generate embeddings for the batch for `contents_4_5`
          expect(llm_class).not_to receive(:new).with(contents_4_5, anything)

          expect { generate_embeddings }.to raise_error(
            StandardError,
            "Token limit exceeded for single content input: \"some error\""
          )
        end
      end

      # We anticipate this to be a possible scenario where we have explicitly set the batch size,
      # but we are still getting a "token limits exceeded" error. We need to make sure that the
      # expected behavior happens.
      context 'when combined with explicit batch_size' do
        subject(:generate_embeddings) do
          described_class.generate_embeddings(
            contents,
            unit_primitive: unit_primitive,
            model: model,
            user: user,
            batch_size: batch_size
          )
        end

        let(:batch_size) { 3 }

        it 'recursively splits the batch size and eventually succeeds' do
          # the processing flow here is:
          # - call `generate_embeddings` with input %w[content-1 content-2 content-3 content-4 content-5]
          # - the original input is split by the specified batch_size=3
          #   - batch %w[content-1 content-2 content-3]
          #     - embeddings generation for this batch throws a "token limits exceeded" error
          #     - this batch is further split in 2
          #       - %w[content-1 content-2] - embeddings generation OK
          #       - %w[content-3]           - embeddings generation OK
          #   - batch %w[content-4 content-5] - embeddings generation OK

          # for %w[content-1 content-2 content-3 content-4 content-5]
          # it does not try to generate embeddings for the entire `contents` input (size = 5)
          # because the specified batch_size is 3
          expect(llm_class).not_to receive(:new).with(contents_batch_size_5, anything)

          # for %w[content-1 content-2 content-3] - this is the batch that throws a "token limits exceeded" error
          expect(llm_class).to receive(:new).with(contents_batch_size_3, anything).ordered

          # processing for:
          #   - %w[content-1 content-2]
          #   - %w[content-3]
          #   - %w[content-4 content-5]
          expect(llm_class).to receive(:new).with(contents_1_2, anything).ordered
          expect(llm_class).to receive(:new).with(contents_3, anything).ordered
          expect(llm_class).to receive(:new).with(contents_4_5, anything).ordered

          # after the explicit batch splitting due to batch_size +
          #      + the automatic batch splitting due to "token limits exceeded" error
          # we still expect the call to `generate_embeddings` to
          # return the embeddings for *all* the contents of the original batch
          expect(generate_embeddings).to eq embeddings
        end
      end
    end

    describe 'batching by batch_size parameter' do
      before do
        allow(llm_class).to receive(:new) do |arg_contents|
          if arg_contents == contents_batch_1
            embeddings_model_for_batch_1
          elsif arg_contents == contents_batch_2
            embeddings_model_for_batch_2
          end
        end
      end

      let(:embeddings_model_for_batch_1) do
        instance_double(llm_class, execute: [[1, 1], [2, 2], [3, 3]])
      end

      let(:embeddings_model_for_batch_2) do
        instance_double(llm_class, execute: [[4, 4], [5, 5]])
      end

      let(:contents_batch_1) { %w[content-1 content-2 content-3] }
      let(:contents_batch_2) { %w[content-4 content-5] }

      let(:batch_size) { 3 }

      subject(:generate_embeddings) do
        described_class.generate_embeddings(
          contents,
          unit_primitive: unit_primitive,
          model: model,
          user: user,
          batch_size: batch_size
        )
      end

      context 'when the input contents count is greater than the batch size' do
        it 'generates embeddings in batches' do
          # the `contents` input is batched
          expect(llm_class).to receive(:new).with(contents_batch_1, anything).ordered
          expect(llm_class).to receive(:new).with(contents_batch_2, anything).ordered

          # we still expect the call to `generate_embeddings` to
          # return the embeddings for *all* the contents of the original batch
          expect(generate_embeddings).to eq embeddings
        end
      end

      context 'when the caller explicitly specifies a `nil` batch_size' do
        before do
          # we are stubbing `DEFAULT_BATCH_SIZE` to 3
          # since we've already setup the mocks for it
          stub_const("#{described_class}::DEFAULT_BATCH_SIZE", 3)
        end

        subject(:generate_embeddings) do
          described_class.generate_embeddings(
            contents,
            unit_primitive: unit_primitive,
            model: model,
            user: user,
            batch_size: nil
          )
        end

        it 'uses the default batch size' do
          # the `contents` input is batched
          expect(llm_class).to receive(:new).with(contents_batch_1, anything).ordered
          expect(llm_class).to receive(:new).with(contents_batch_2, anything).ordered

          # we still expect the call to `generate_embeddings` to
          # return the embeddings for *all* the contents of the original batch
          expect(generate_embeddings).to eq embeddings
        end
      end
    end

    describe 'unit_primitive parameter' do
      context 'when the given unit_primitive is nil' do
        subject(:generate_embeddings) do
          described_class.generate_embeddings(
            contents,
            unit_primitive: nil,
            model: model,
            user: user
          )
        end

        it 'uses the default unit primitive' do
          expect(llm_class).to receive(:new).with(
            contents,
            user: user,
            tracking_context: { action: 'embedding' },
            unit_primitive: 'generate_embeddings_codebase',
            model: model
          )

          expect(generate_embeddings).to eq embeddings
        end
      end
    end
  end
end
