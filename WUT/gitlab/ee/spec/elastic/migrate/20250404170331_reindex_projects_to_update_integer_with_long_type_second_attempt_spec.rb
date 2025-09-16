# frozen_string_literal: true

require 'spec_helper'
require File.expand_path(
  'ee/elastic/migrate/20250404170331_reindex_projects_to_update_integer_with_long_type_second_attempt.rb'
)

RSpec.describe ReindexProjectsToUpdateIntegerWithLongTypeSecondAttempt, feature_category: :global_search do
  let(:version) { 20250404170331 }
  let(:migration) { described_class.new(version) }
  let(:task) { Search::Elastic::ReindexingTask.last }
  let(:targets) { %w[Project] }

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
