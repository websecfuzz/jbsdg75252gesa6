# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250623160142_backfill_traversal_ids_in_notes.rb')

RSpec.describe BackfillTraversalIdsInNotes, :elastic_delete_by_query, :sidekiq_inline, feature_category: :global_search do
  let(:version) { 20250623160142 }

  include_examples 'migration reindex based on schema_version' do
    let(:expected_throttle_delay) { 30.seconds }
    let(:expected_batch_size) { 10_000 }
    let(:objects) do
      [create(:note_on_issue), create(:note_on_project_snippet),
        create(:note_on_commit), create(:note_on_merge_request)]
    end
  end
end
