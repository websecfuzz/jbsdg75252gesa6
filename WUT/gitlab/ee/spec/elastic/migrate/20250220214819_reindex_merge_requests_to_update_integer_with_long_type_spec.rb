# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250220214819_reindex_merge_requests_to_update_integer_with_long_type.rb')

RSpec.describe ReindexMergeRequestsToUpdateIntegerWithLongType, :elastic_delete_by_query, :sidekiq_inline, feature_category: :global_search do
  let(:version) { 20250220214819 }
  let(:migration) { described_class.new(version) }
  let(:task) { Search::Elastic::ReindexingTask.last }
  let(:targets) { %w[MergeRequest] }

  it 'does not have migration options set', :aggregate_failures do
    expect(migration).not_to be_batched
    expect(migration).not_to be_retry_on_failure
  end

  describe '#migrate', :aggregate_failures do
    it 'creates reindexing task with correct target and options' do
      expect { migration.migrate }.to change { Search::Elastic::ReindexingTask.count }.by(1)
      expect(task.targets).to eq(targets)
      expect(task.options).to eq('skip_pending_migrations_check' => true)
    end
  end

  describe '#completed?' do
    it 'always returns true' do
      expect(migration.completed?).to be(true)
    end
  end
end
