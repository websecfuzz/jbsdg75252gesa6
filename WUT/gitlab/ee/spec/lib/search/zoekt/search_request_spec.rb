# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::SearchRequest, feature_category: :global_search do
  let_it_be(:node1) { create(:zoekt_node) }
  let_it_be(:node2) { create(:zoekt_node) }

  describe '#as_json' do
    subject(:json_representation) do
      described_class.new(query: 'test', targets: { node1.id => [1, 2, 3], node2.id => [4, 5, 6] }).as_json
    end

    it 'returns a valid JSON representation of the search request' do
      expect(json_representation).to eq({
        version: 2,
        timeout: '120s',
        num_context_lines: 20,
        max_file_match_window: 1000,
        max_file_match_results: 5,
        max_line_match_window: 500,
        max_line_match_results: 10,
        max_line_match_results_per_file: 3,
        forward_to: [
          {
            query: {
              and: { children: [{ query_string: { query: 'test' } }, { repo_ids: [1, 2, 3] }] }
            },
            endpoint: node1.search_base_url
          },
          {
            query: {
              and: { children: [{ query_string: { query: 'test' } }, { repo_ids: [4, 5, 6] }] }
            },
            endpoint: node2.search_base_url
          }
        ]
      })
    end
  end
end
