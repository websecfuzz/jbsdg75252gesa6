# frozen_string_literal: true

module Gitlab
  module CodeOwners
    class File
      include ::Gitlab::Utils::StrongMemoize

      # `FNM_DOTMATCH` makes sure we also match files starting with a `.`
      # `FNM_PATHNAME` makes sure ** matches path separators
      FNMATCH_FLAGS = (::File::FNM_DOTMATCH | ::File::FNM_PATHNAME).freeze

      # Maxmimum number of references to validate
      # This maximum is currently not based on any benchmark
      MAX_REFERENCES = 200

      def initialize(blob)
        @blob = blob
        @errors = Errors.new
      end

      attr_reader :errors

      def parsed_data
        @parsed_data ||= get_parsed_data
      end

      # Since an otherwise "empty" CODEOWNERS file will still return a default
      #   section of "codeowners", a la
      #
      #   {"codeowners"=>{}}
      #
      #   ...we must cycle through all the actual values parsed into each
      #   section to determine if the file is empty or not.
      #
      def empty?
        parsed_data.values.all?(&:empty?)
      end

      def path
        @blob&.path
      end

      def sections
        parsed_data.keys
      end

      # Check whether any of the entries is optional
      # In cases of the conflicts:
      #
      # [Documentation]
      # *.go @user
      #
      # ^[Documentation]
      # *.rb @user
      #
      # The Documentation section is still required
      def optional_section?(section)
        entries = parsed_data[section]&.values
        entries.present? && entries.all?(&:optional?)
      end

      def entries_for_path(path)
        path = "/#{path}" unless path.start_with?('/')

        matches = []

        parsed_data.each do |_, section_entries|
          matching_patterns = section_entries.keys.reverse.select { |pattern| path_matches?(pattern, path) }
          matching_entries = matching_patterns.map { |pattern| section_entries[pattern] }

          next if matching_entries.any?(&:exclusion?)

          matches << matching_entries.first.dup if matching_entries.any?
        end

        matches
      end

      def valid?
        parsed_data

        OwnerValidation::Process.new(project, self).execute

        errors.none?
      end

      private

      def project
        @blob&.repository&.project
      end

      def data
        return "" if @blob.nil? || @blob.binary?

        @blob.data
      end

      def get_parsed_data
        current_section = Section.new(name: Section::DEFAULT)
        parsed_sectional_data = {
          current_section.name => {}
        }

        data.lines.each.with_index(1) do |line, line_number|
          line = line.strip

          next if skip?(line)

          section_parser = SectionParser.new(line, parsed_sectional_data, line_number)

          # Report errors even if the section is successfully parsed
          errors.merge(section_parser.errors) unless section_parser.valid?

          # If this line is a section header, set current_section to the parsed
          # section.
          #
          # Unparsable section headers will be skipped. An error is added to
          # aid the end user.
          if section_parser.section_header?
            current_section = section_parser.section
            parsed_sectional_data[current_section.name] ||= {}
          elsif !section_parser.unparsable_section_header?
            parse_entry(line, parsed_sectional_data, current_section, line_number)
          end
        end

        parsed_sectional_data
      end

      def parse_entry(line, parsed, section, line_number)
        pattern, entry_owners, is_exclusion_pattern = extract_entry_info(line)
        normalized_pattern = normalize_pattern(pattern)
        owners = validate_and_get_owners(entry_owners, section, line_number) unless is_exclusion_pattern

        parsed[section.name][normalized_pattern] = Entry.new(
          pattern,
          owners,
          section: section.name,
          optional: section.optional,
          approvals_required: section.approvals,
          exclusion: is_exclusion_pattern,
          line_number: line_number
        )
      end

      def extract_entry_info(line)
        pattern, _separator, entry_owners = line.partition(/(?<!\\)\s+/)

        is_exclusion_pattern = pattern.start_with?('!')
        pattern = pattern[1..] if is_exclusion_pattern

        [pattern, entry_owners, is_exclusion_pattern]
      end

      def validate_and_get_owners(entry_owners, section, line_number)
        if entry_owners.split.any? { |owner| invalid_owner?(owner) }
          errors.add(:malformed_entry_owner, line_number)
        end

        owners = entry_owners.presence || section.default_owners
        errors.add(:missing_entry_owner, line_number) if owners.blank?

        owners
      end

      def invalid_owner?(owner)
        ReferenceExtractor.new(owner).references.blank?
      end

      def skip?(line)
        line.blank? || line.starts_with?('#')
      end

      def normalize_pattern(pattern)
        return '/**/*' if pattern == '*'

        # Remove `\` when escaping `\#`
        pattern = pattern.sub(/\A\\#/, '#')
        # Replace all whitespace preceded by a \ with a regular whitespace
        pattern = pattern.gsub(/\\\s+/, ' ')

        unless pattern.start_with?('/')
          pattern = "/**/#{pattern}"
        end

        if pattern.end_with?('/')
          pattern = "#{pattern}**/*"
        end

        pattern
      end

      def path_matches?(pattern, path)
        ::File.fnmatch?(pattern, path, FNMATCH_FLAGS)
      end
    end
  end
end
