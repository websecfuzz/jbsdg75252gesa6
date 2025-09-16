# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Templates::ReviewMergeRequest, feature_category: :code_review_workflow do
  let(:diffs_and_paths) do
    {
      'UPDATED.md' => <<~RAWDIFF
      @@ -1,4 +1,4 @@
       # UPDATED

      -Welcome
      -This is an updated file
      +Welcome!
      +This is an updated file.
      @@ -10,3 +10,3 @@
       # ANOTHER HUNK

      -This is an old line
      +This is a new line
      RAWDIFF
    }
  end

  let(:new_path) { 'UPDATED.md' }
  let(:user) { build(:user) }
  let(:mr_title) { 'Fix typos in welcome message' }
  let(:mr_description) { 'Improving readability by fixing typos and adding proper punctuation.' }
  let(:files_content) do
    {
      'UPDATED.md' =>
        "@@ -1,4 +1,4 @@\n # UPDATED\n-Welcome\n-This is an updated file\n+Welcome!\n+This is an updated file."
    }
  end

  describe '#to_prompt_inputs' do
    let(:expected_diff_lines) do
      <<~DIFF.chomp
        <file_diff filename="UPDATED.md">
        <line type="context" old_line="1" new_line="1"># UPDATED</line>
        <line type="context" old_line="2" new_line="2"></line>
        <line type="deleted" old_line="3" new_line="">Welcome</line>
        <line type="deleted" old_line="4" new_line="">This is an updated file</line>
        <line type="added" old_line="" new_line="3">Welcome!</line>
        <line type="added" old_line="" new_line="4">This is an updated file.</line>
        <chunk_header>@@ -10,3 +10,3 @@</chunk_header>
        <line type="context" old_line="10" new_line="10"># ANOTHER HUNK</line>
        <line type="context" old_line="11" new_line="11"></line>
        <line type="deleted" old_line="12" new_line="">This is an old line</line>
        <line type="added" old_line="" new_line="12">This is a new line</line>
        </file_diff>
      DIFF
    end

    let(:expected_full_file_intro) do
      " You will also be provided with the original content of modified files (before changes). " \
        "Newly added files are not included as their full content is already in the diffs."
    end

    let(:expected_full_content_section) do
      <<~CONTENT.chomp
        Original file content (before changes):

        Check for code duplication, redundancies, and inconsistencies.

        <full_file filename="UPDATED.md">
        @@ -1,4 +1,4 @@
         # UPDATED
        -Welcome
        -This is an updated file
        +Welcome!
        +This is an updated file.
        </full_file>
      CONTENT
    end

    subject(:prompt_inputs) do
      described_class.new(
        mr_title: mr_title,
        mr_description: mr_description,
        diffs_and_paths: diffs_and_paths,
        files_content: files_content,
        user: user
      ).to_prompt_inputs
    end

    shared_examples 'builds prompt inputs' do
      it 'returns prompt inputs' do
        expect(prompt_inputs).to eq({
          mr_title: mr_title,
          mr_description: mr_description,
          diff_lines: expected_diff_lines,
          full_file_intro: expected_full_file_intro,
          full_content_section: expected_full_content_section,
          custom_instructions_section: ""
        })
      end
    end

    it_behaves_like 'builds prompt inputs'

    context 'when files_content is empty' do
      let(:files_content) { {} }
      let(:expected_full_file_intro) { '' }
      let(:expected_full_content_section) { '' }

      it_behaves_like 'builds prompt inputs'
    end

    context 'with multiple files' do
      let(:diffs_and_paths) do
        {
          'UPDATED.md' =>
          "@@ -1,4 +1,4 @@\n # UPDATED\n-Welcome\n-This is an updated file\n+Welcome!\n+This is an updated file.",
          'OTHER.md' => "@@ -5,3 +5,3 @@\n # CONTENT\n-This is old content\n+This is updated content"
        }
      end

      let(:files_content) do
        {
          'UPDATED.md' => "# UPDATED\nWelcome!\nThis is an updated file.\n\n...",
          'OTHER.md' => "Some header\n\n...\n\n# CONTENT\n\nThis is updated content"
        }
      end

      let(:expected_diff_lines) do
        <<~DIFF.chomp
          <file_diff filename="UPDATED.md">
          <line type="context" old_line="1" new_line="1"># UPDATED</line>
          <line type="deleted" old_line="2" new_line="">Welcome</line>
          <line type="deleted" old_line="3" new_line="">This is an updated file</line>
          <line type="added" old_line="" new_line="2">Welcome!</line>
          <line type="added" old_line="" new_line="3">This is an updated file.</line>
          </file_diff>

          <file_diff filename="OTHER.md">
          <chunk_header>@@ -5,3 +5,3 @@</chunk_header>
          <line type="context" old_line="5" new_line="5"># CONTENT</line>
          <line type="deleted" old_line="6" new_line="">This is old content</line>
          <line type="added" old_line="" new_line="6">This is updated content</line>
          </file_diff>
        DIFF
      end

      let(:expected_full_content_section) do
        <<~CONTENT.chomp
          Original file content (before changes):

          Check for code duplication, redundancies, and inconsistencies.

          <full_file filename="UPDATED.md">
          # UPDATED
          Welcome!
          This is an updated file.

          ...
          </full_file>

          <full_file filename="OTHER.md">
          Some header

          ...

          # CONTENT

          This is updated content
          </full_file>
        CONTENT
      end

      it_behaves_like 'builds prompt inputs'
    end

    context 'with custom instructions' do
      let(:custom_instructions) do
        [
          {
            name: 'Ruby Style Guide',
            instructions: 'Follow Ruby style conventions and best practices',
            glob_pattern: '*.rb'
          },
          {
            name: 'Markdown Standards',
            instructions: 'Check for proper markdown formatting and structure',
            glob_pattern: '*.md'
          },
          {
            name: 'Security Review',
            instructions: 'Focus on security vulnerabilities and data validation',
            glob_pattern: '*.rb'
          }
        ]
      end

      subject(:prompt_inputs) do
        described_class.new(
          mr_title: mr_title,
          mr_description: mr_description,
          diffs_and_paths: diffs_and_paths,
          files_content: files_content,
          user: user,
          custom_instructions: custom_instructions
        ).to_prompt_inputs
      end

      it 'formats custom instructions section correctly' do
        expect(prompt_inputs[:custom_instructions_section]).to eq <<~SECTION
          Custom Review Instructions:
          <custom_instructions>
          You must also apply the following custom review instructions. Each instruction specifies which files it applies to:

          For files matching "*.rb" (Ruby Style Guide):
          Follow Ruby style conventions and best practices

          For files matching "*.md" (Markdown Standards):
          Check for proper markdown formatting and structure

          For files matching "*.rb" (Security Review):
          Focus on security vulnerabilities and data validation

          IMPORTANT: Only apply each custom instruction to files that match its specified pattern. If a file doesn't match any custom instruction pattern, only apply the standard review criteria.

          FORMATTING REQUIREMENT: When generating a comment based on a custom instruction, you MUST format it as follows:
          "According to custom instructions in '[instruction_name]': [your comment here]"

          For example:
          "According to custom instructions in 'Security Best Practices': This API endpoint should validate input parameters to prevent SQL injection."

          This formatting is ONLY required for comments that are triggered by custom instructions. Regular review comments based on standard review criteria should NOT include this prefix.
          </custom_instructions>
        SECTION
      end

      context 'when multiple patterns exist for same instruction group' do
        let(:custom_instructions) do
          [
            {
              name: 'General Code Review',
              instructions: 'Review for code quality and best practices',
              glob_pattern: '*.rb'
            },
            {
              name: 'General Code Review',
              instructions: 'Check for performance optimizations and memory leaks',
              glob_pattern: '**/*.rb'
            }
          ]
        end

        it 'treats each instruction individually even with same name' do
          expect(prompt_inputs[:custom_instructions_section]).to eq <<~SECTION
            Custom Review Instructions:
            <custom_instructions>
            You must also apply the following custom review instructions. Each instruction specifies which files it applies to:

            For files matching "*.rb" (General Code Review):
            Review for code quality and best practices

            For files matching "**/*.rb" (General Code Review):
            Check for performance optimizations and memory leaks

            IMPORTANT: Only apply each custom instruction to files that match its specified pattern. If a file doesn't match any custom instruction pattern, only apply the standard review criteria.

            FORMATTING REQUIREMENT: When generating a comment based on a custom instruction, you MUST format it as follows:
            "According to custom instructions in '[instruction_name]': [your comment here]"

            For example:
            "According to custom instructions in 'Security Best Practices': This API endpoint should validate input parameters to prevent SQL injection."

            This formatting is ONLY required for comments that are triggered by custom instructions. Regular review comments based on standard review criteria should NOT include this prefix.
            </custom_instructions>
          SECTION
        end
      end

      context 'when custom instructions is empty' do
        let(:custom_instructions) { [] }

        it 'returns empty string for custom instructions section' do
          expect(prompt_inputs[:custom_instructions_section]).to eq("")
        end
      end
    end
  end
end
