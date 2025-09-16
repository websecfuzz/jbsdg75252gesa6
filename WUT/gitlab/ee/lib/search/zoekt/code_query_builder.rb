# frozen_string_literal: true

module Search
  module Zoekt
    class CodeQueryBuilder < QueryBuilder
      def build
        { query: build_payload }
      end

      private

      def build_payload
        # NOTE: in the future, we are going to use more granular AST filters instead of relying on query_string
        base_query = Filters.by_query_string(query)
        return base_query if options[:repo_ids].blank?

        Filters.and_filters(base_query, Filters.by_repo_ids(options[:repo_ids]))
      end
    end
  end
end
