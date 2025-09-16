# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250516124136_backfill_work_item_milestone_data.rb')

RSpec.describe BackfillWorkItemMilestoneData, feature_category: :global_search do
  let(:version) { 20250516124136 }

  describe 'migration', :elastic_delete_by_query, :sidekiq_inline do
    include_examples 'migration reindex based on schema_version' do
      let(:expected_throttle_delay) { 1.minute }
      let(:expected_batch_size) { 10_000 }

      let_it_be(:project) { create(:project) }
      let_it_be(:milestone) { create(:milestone, project: project) }

      let(:objects) do
        create_list(:work_item, 2, project: project, milestone: milestone) +
          create_list(:work_item, 2, project: project)
      end
    end
  end
end
