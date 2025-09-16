# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Code::MarkRepositoryAsReadyEventWorker, feature_category: :global_search do
  let(:event) { Ai::ActiveContext::Code::MarkRepositoryAsReadyEvent.new(data: {}) }
  let_it_be(:connection) { create(:ai_active_context_connection) }
  let_it_be(:collection) do
    create(:ai_active_context_collection, :code_embeddings_with_versions, connection_id: connection.id)
  end

  let_it_be(:enabled_namespace) do
    create(:ai_active_context_code_enabled_namespace, active_context_connection: connection)
  end

  subject(:execute) { consume_event(subscriber: described_class, event: event) }

  describe '#handle_event', :clean_gitlab_redis_shared_state do
    context 'when indexing is enabled' do
      before do
        allow(::Ai::ActiveContext::Collections::Code).to receive(:indexing?).and_return(true)
      end

      context 'when there are multiple repositories with embedding indexing in progress' do
        let(:key1) { 'hash1' }
        let(:key2) { 'hash2' }
        let(:key3) { 'hash3' }

        let!(:repository1) do
          create(:ai_active_context_code_repository,
            enabled_namespace: enabled_namespace,
            state: :embedding_indexing_in_progress,
            connection_id: connection.id,
            initial_indexing_last_queued_item: key1
          )
        end

        let!(:repository2) do
          create(:ai_active_context_code_repository,
            enabled_namespace: enabled_namespace,
            state: :embedding_indexing_in_progress,
            connection_id: connection.id,
            initial_indexing_last_queued_item: key2
          )
        end

        let!(:repository3) do
          create(:ai_active_context_code_repository,
            enabled_namespace: enabled_namespace,
            state: :embedding_indexing_in_progress,
            connection_id: connection.id,
            initial_indexing_last_queued_item: key3
          )
        end

        context 'when all repositories have embedding fields' do
          before do
            allow(Ai::ActiveContext::Collections::Code).to receive(:search).and_return(
              [
                { 'id' => key1, 'embeddings_v1' => [1, 2, 3] },
                { 'id' => key2, 'embeddings_v1' => [4, 5, 6] },
                { 'id' => key3, 'embeddings_v1' => [7, 8, 9] }
              ]
            )
          end

          it 'changes all repositories status to ready in a single bulk update' do
            expect { execute }.to change { repository1.reload.state }.from('embedding_indexing_in_progress').to('ready')
              .and change { repository2.reload.state }.from('embedding_indexing_in_progress').to('ready')
              .and change { repository3.reload.state }.from('embedding_indexing_in_progress').to('ready')
          end
        end

        context 'when only some repositories have embedding fields' do
          before do
            allow(Ai::ActiveContext::Collections::Code).to receive(:search).and_return(
              [
                { 'id' => key1, 'embeddings_v1' => [1, 2, 3] },
                { 'id' => key3, 'embeddings_v1' => [7, 8, 9] }
              ]
            )
          end

          it 'only updates repositories with embedding fields' do
            expect { execute }.to change { repository1.reload.state }.from('embedding_indexing_in_progress').to('ready')
              .and change { repository3.reload.state }.from('embedding_indexing_in_progress').to('ready')
              .and not_change { repository2.reload.state }.from('embedding_indexing_in_progress')
          end
        end

        context 'when none of the repositories have embedding fields' do
          before do
            allow(Ai::ActiveContext::Collections::Code).to receive(:search).and_return([])
          end

          it 'does not update any repositories' do
            expect { execute }.to not_change { repository1.reload.state }.from('embedding_indexing_in_progress')
              .and not_change { repository2.reload.state }.from('embedding_indexing_in_progress')
              .and not_change { repository3.reload.state }.from('embedding_indexing_in_progress')
          end
        end
      end

      context 'when some repositories have no initial_indexing_last_queued_item' do
        let(:key) { 'hash' }

        let!(:repository_with_item) do
          create(:ai_active_context_code_repository,
            enabled_namespace: enabled_namespace,
            state: :embedding_indexing_in_progress,
            connection_id: connection.id,
            initial_indexing_last_queued_item: key
          )
        end

        let!(:repository_without_item) do
          create(:ai_active_context_code_repository,
            enabled_namespace: enabled_namespace,
            state: :embedding_indexing_in_progress,
            connection_id: connection.id,
            initial_indexing_last_queued_item: nil
          )
        end

        before do
          allow(Ai::ActiveContext::Collections::Code).to receive(:search).and_return(
            [{ 'id' => key, 'embeddings_v1' => [1, 2, 3] }]
          )
        end

        it 'only processes repositories with an item' do
          expect { execute }.to change {
            repository_with_item.reload.state
          }.from('embedding_indexing_in_progress').to('ready')
            .and not_change { repository_without_item.reload.state }.from('embedding_indexing_in_progress')
        end
      end

      context 'when there are no repositories with embedding indexing in progress' do
        let!(:repository) do
          create(:ai_active_context_code_repository,
            enabled_namespace: enabled_namespace,
            state: :pending,
            connection_id: connection.id
          )
        end

        it 'does nothing' do
          expect(::ActiveContext).not_to receive(:adapter)

          execute
        end
      end
    end

    context 'when indexing is disabled' do
      before do
        allow(::Ai::ActiveContext::Collections::Code).to receive(:indexing?).and_return(false)
      end

      it 'does nothing' do
        expect(::ActiveContext).not_to receive(:adapter)

        execute
      end
    end
  end
end
