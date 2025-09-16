# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Code::RepositoryIndexService, feature_category: :global_search do
  let_it_be(:repository) { create(:ai_active_context_code_repository, state: :pending) }

  describe '.enqueue_pending_jobs' do
    before do
      allow(::Ai::ActiveContext::Code::Repository).to receive_message_chain(:pending, :with_active_connection)
        .and_return(::Ai::ActiveContext::Code::Repository.all)
    end

    it 'enqueues RepositoryIndexWorker jobs for eligible repositories' do
      expect(Ai::ActiveContext::Code::RepositoryIndexWorker).to receive(:perform_async).with(repository.id)

      described_class.enqueue_pending_jobs
    end
  end
end
