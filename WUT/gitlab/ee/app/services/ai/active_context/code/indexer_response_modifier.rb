# frozen_string_literal: true

module Ai
  module ActiveContext
    module Code
      class IndexerResponseModifier
        SECTION_BREAK = '--section-start--'
        # This regex extracts chunk IDs from the indexer output.
        # It matches the section containing IDs between the SECTION_BREAK markers,
        # specifically looking for a section that has "id" as its header.
        # It captures all lines between the "id" header and either the next section marker
        # or a JSON object (lines starting with '{').
        # The 'match[1]' will contain all the IDs with newlines, which are then split and stripped.
        #
        # Example output:
        #
        # --section-start--
        # version,build_time
        # v5.6.0-16-gb587744-dev,2025-06-24-0800 UTC
        # --section-start--
        # id
        # hash123
        # hash456
        ID_REGEX = /#{SECTION_BREAK}\s*\nid\n([\s\S]*?)(?=\s*#{SECTION_BREAK}|\s*\{|\z)/m

        def self.extract_ids(result)
          return [] if result.nil? || result.empty?

          match = result.match(ID_REGEX)

          return [] unless match

          match[1].split("\n").map(&:strip).reject(&:empty?)
        end
      end
    end
  end
end
