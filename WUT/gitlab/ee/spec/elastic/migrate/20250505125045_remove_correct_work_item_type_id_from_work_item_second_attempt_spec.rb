# frozen_string_literal: true

require 'spec_helper'
require File.expand_path(
  'ee/elastic/migrate/20250505125045_remove_correct_work_item_type_id_from_work_item_second_attempt.rb'
)

RSpec.describe RemoveCorrectWorkItemTypeIdFromWorkItemSecondAttempt, :elastic_delete_by_query, :sidekiq_inline, feature_category: :global_search do
  let(:version) { 20250505125045 }

  include_examples 'migration removes field' do
    let(:expected_throttle_delay) { 1.minute }
    let(:objects) { create_list(:work_item, 6) }
    let(:index_name) { ::Search::Elastic::Types::WorkItem.index_name }
    let(:field) { :correct_work_item_type_id }
    let(:type) { 'long' }
  end
end
