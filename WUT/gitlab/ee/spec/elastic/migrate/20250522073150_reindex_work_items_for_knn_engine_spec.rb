# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250522073150_reindex_work_items_for_knn_engine.rb')

RSpec.describe ReindexWorkItemsForKnnEngine, feature_category: :global_search do
  let(:version) { 20250522073150 }
  let(:migration) { described_class.new(version) }

  describe 'migration' do
    before do
      skip 'migration is skipped' if migration.skip_migration?
    end

    it 'does not have migration options set', :aggregate_failures do
      expect(migration).not_to be_batched
      expect(migration).not_to be_retry_on_failure
    end

    describe '#migrate' do
      it 'creates reindexing task with correct target and options' do
        expect { migration.migrate }.to change { Search::Elastic::ReindexingTask.count }.by(1)
        task = Search::Elastic::ReindexingTask.last
        expect(task.targets).to eq(%w[WorkItem])
        expect(task.options).to eq({ 'skip_pending_migrations_check' => true })
      end
    end

    describe '#completed?' do
      it 'always returns true' do
        expect(migration.completed?).to be_truthy
      end
    end
  end
end
