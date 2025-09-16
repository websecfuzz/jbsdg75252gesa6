# frozen_string_literal: true

module Search
  module Zoekt
    class QueryBuilder
      def self.build(...)
        new(...).build
      end

      def initialize(query:, options: {})
        @query = query
        # allow extra_options to overwrite base_options
        @options = options.merge(base_options.merge(extra_options))
      end

      def build
        raise NotImplementedError
      end

      private

      attr_reader :query, :options

      def base_options
        {}
      end

      # Subclasses should override this method to provide additional options to builder
      def extra_options
        {}
      end
    end
  end
end
