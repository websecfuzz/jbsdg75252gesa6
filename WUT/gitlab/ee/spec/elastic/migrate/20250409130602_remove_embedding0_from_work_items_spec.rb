# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250409130602_remove_embedding0_from_work_items.rb')

RSpec.describe RemoveEmbedding0FromWorkItems, :elastic_delete_by_query, :sidekiq_inline, feature_category: :global_search do
  let(:version) { 20250409130602 }

  before do
    skip 'migration is skipped' unless Gitlab::Elastic::Helper.default.vectors_supported?(:elasticsearch)
  end

  include_examples 'migration removes field' do
    let(:expected_throttle_delay) { 1.minute }
    let(:objects) { create_list(:work_item, 6) }
    let(:index_name) { ::Search::Elastic::Types::WorkItem.index_name }
    let(:field) { :embedding_0 }
    let(:mapping) { { type: 'dense_vector', dims: 768, index: true, similarity: 'cosine' } }
    let(:value) { Array.new(768, 1) }
  end
end
