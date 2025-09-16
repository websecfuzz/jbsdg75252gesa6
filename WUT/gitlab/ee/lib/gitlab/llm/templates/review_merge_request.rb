# frozen_string_literal: true

module Gitlab
  module Llm
    module Templates
      class ReviewMergeRequest
        def initialize(mr_title:, mr_description:, diffs_and_paths:, user:, files_content: {}, custom_instructions: [])
          @mr_title = mr_title
          @mr_description = mr_description
          @diffs_and_paths = diffs_and_paths
          @files_content = files_content
          @user = user
          @custom_instructions = custom_instructions
        end

        def to_prompt_inputs
          {
            mr_title: mr_title,
            mr_description: mr_description,
            diff_lines: all_diffs_formatted,
            full_file_intro: files_content.present? ? full_file_intro_text : "",
            full_content_section: files_content.present? ? full_content_section_text : "",
            custom_instructions_section: format_custom_instructions_section
          }
        end

        private

        def full_file_intro_text
          " You will also be provided with the original content of modified files (before changes). " \
            "Newly added files are not included as their full content is already in the diffs."
        end

        def full_content_section_text
          <<~SECTION.chomp
            Original file content (before changes):

            Check for code duplication, redundancies, and inconsistencies.

            #{all_files_content_formatted}
          SECTION
        end

        def format_custom_instructions_section
          return "" if custom_instructions.empty?

          <<~SECTION
            Custom Review Instructions:
            <custom_instructions>
            You must also apply the following custom review instructions. Each instruction specifies which files it applies to:

            #{format_custom_instructions_list}

            IMPORTANT: Only apply each custom instruction to files that match its specified pattern. If a file doesn't match any custom instruction pattern, only apply the standard review criteria.

            FORMATTING REQUIREMENT: When generating a comment based on a custom instruction, you MUST format it as follows:
            "According to custom instructions in '[instruction_name]': [your comment here]"

            For example:
            "According to custom instructions in 'Security Best Practices': This API endpoint should validate input parameters to prevent SQL injection."

            This formatting is ONLY required for comments that are triggered by custom instructions. Regular review comments based on standard review criteria should NOT include this prefix.
            </custom_instructions>
          SECTION
        end

        def format_custom_instructions_list
          custom_instructions.map do |instruction|
            "For files matching \"#{instruction[:glob_pattern]}\" (#{instruction[:name]}):\n" \
              "#{instruction[:instructions].strip}"
          end.join("\n\n")
        end

        def all_diffs_formatted
          diffs_and_paths.map do |path, raw_diff|
            formatted_diff = format_diff(raw_diff)
            %(<file_diff filename="#{path}">\n#{formatted_diff}\n</file_diff>)
          end.join("\n\n")
        end

        def all_files_content_formatted
          files_content.map do |path, content|
            %(<full_file filename="#{path}">\n#{content}\n</full_file>)
          end.join("\n\n")
        end

        def format_diff(raw_diff)
          lines = Gitlab::Diff::Parser.new.parse(raw_diff.lines)

          lines.map do |line|
            format_diff_line(line)
          end.join("\n")
        end

        def format_diff_line(line)
          if line.type == 'match'
            %(<chunk_header>#{line.text}</chunk_header>)
          else
            # NOTE: We are passing in diffs without the prefixes as the LLM seems to get confused sometimes and thinking
            # that's a part of the actual content.
            text = line.text(prefix: false)
            type = if line.added?
                     'added'
                   elsif line.removed?
                     'deleted'
                   else
                     'context'
                   end

            %(<line type="#{type}" old_line="#{line.old_line}" new_line="#{line.new_line}">#{text}</line>)
          end
        end

        attr_reader :mr_title, :mr_description, :diffs_and_paths, :files_content, :user, :custom_instructions
      end
    end
  end
end
