# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Ingestion::Context, feature_category: :vulnerability_management do
  subject(:context) { described_class.new }

  describe '#run_after_sec_commit' do
    it 'raises an error when called without a block' do
      expect { context.run_after_sec_commit }.to raise_error(ArgumentError)
    end

    it 'does not execute work until run_sec_after_commit_tasks is called' do
      allow(Vulnerabilities::MarkDroppedAsResolvedWorker).to receive(:perform_async).and_call_original

      SecApplicationRecord.transaction do
        context.run_after_sec_commit { Vulnerabilities::MarkDroppedAsResolvedWorker.perform_async(1, [1]) }
      end

      expect(Vulnerabilities::MarkDroppedAsResolvedWorker).not_to have_received(:perform_async)

      context.run_sec_after_commit_tasks

      expect(Vulnerabilities::MarkDroppedAsResolvedWorker).to have_received(:perform_async)
    end
  end
end
