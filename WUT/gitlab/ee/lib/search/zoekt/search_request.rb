# frozen_string_literal: true

module Search
  module Zoekt
    class SearchRequest
      def initialize(query:, **options)
        @query = query
        @options = options
      end

      def as_json
        {
          version: 2,
          timeout: options.fetch(:timeout, '120s'),
          num_context_lines: options.fetch(:num_context_lines, 20),
          max_file_match_window: options.fetch(:max_file_match_window, 1000),
          max_file_match_results: options.fetch(:max_file_match_results, 5),
          max_line_match_window: options.fetch(:max_line_match_window, 500),
          max_line_match_results: options.fetch(:max_line_match_results, 10),
          max_line_match_results_per_file: options.fetch(:max_line_match_results_per_file, 3),
          forward_to: build_node_queries_from_targets
        }
      end

      private

      def build_node_queries_from_targets
        raise ArgumentError, 'No targets specified for the search request' unless options[:targets].present?

        options[:targets].filter_map do |node_id, repo_ids|
          node = ::Search::Zoekt::Node.find_by_id(node_id)
          next if node.nil?

          CodeQueryBuilder.build(query: query, options: { repo_ids: repo_ids }).tap do |payload|
            payload[:endpoint] = node.search_base_url
          end
        end
      end

      attr_reader :query, :options
    end
  end
end
