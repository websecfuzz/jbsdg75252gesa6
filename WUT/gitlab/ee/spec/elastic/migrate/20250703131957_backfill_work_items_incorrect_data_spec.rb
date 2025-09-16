# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250703131957_backfill_work_items_incorrect_data.rb')

# See https://docs.gitlab.com/ee/development/testing_guide/best_practices.html#elasticsearch-specs
# for more information on how to write search migration specs for GitLab.
RSpec.describe BackfillWorkItemsIncorrectData, feature_category: :global_search do
  let(:version) { 20250703131957 }

  describe 'migration', :elastic_delete_by_query, :sidekiq_inline do
    include_examples 'migration reindex based on schema_version' do
      let(:expected_throttle_delay) { 30.seconds }
      let(:expected_batch_size) { 10_000 }
      let_it_be(:project) { create(:project) }

      let(:objects) do
        [create(:work_item, weight: nil, health_status: nil, project: project, milestone: nil, labels: [])]
      end
    end
  end
end
