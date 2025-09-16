# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::AiGateway::Completions::ReviewMergeRequest::ResponseBodyParser, feature_category: :code_review_workflow do
  subject(:parser) { described_class.new(body) }

  let(:body) { nil }

  describe '#parse' do
    context 'with valid content' do
      context 'with text only comment' do
        let(:body) do
          <<~RESPONSE
          <review>
          <comment file="example.rb" old_line="1" new_line="2">
          First line of comment
          Second line of comment

          Third line of comment
          </comment>
          </review>
          RESPONSE
        end

        it 'returns the expected comment' do
          comment = parser.comments.sole

          expect(comment.old_line).to eq 1
          expect(comment.new_line).to eq 2
          expect(comment.file).to eq "example.rb"
          expect(comment.content).to eq <<~NOTE_CONTENT
          First line of comment
          Second line of comment

          Third line of comment
          NOTE_CONTENT
        end
      end

      context 'when old_line attribute is empty' do
        let(:body) do
          <<~RESPONSE
            <review>
            <comment file="example.rb" old_line="" new_line="2">
            Example comment
            </comment>
            </review>
          RESPONSE
        end

        it 'returns the expected comment' do
          comment = parser.comments.sole

          expect(comment.old_line).to be_nil
          expect(comment.new_line).to be 2
          expect(comment.file).to eq "example.rb"
          expect(comment.content).to eq <<~NOTE_CONTENT
          Example comment
          NOTE_CONTENT
        end
      end

      context 'when new_line attribute is empty' do
        let(:body) do
          <<~RESPONSE
            <review>
            <comment file="example.rb" old_line="1" new_line="">
            Example comment
            </comment>
            </review>
          RESPONSE
        end

        it 'returns the expected comment' do
          comment = parser.comments.sole

          expect(comment.old_line).to be 1
          expect(comment.new_line).to be_nil
          expect(comment.file).to eq "example.rb"
          expect(comment.content).to eq <<~NOTE_CONTENT
          Example comment
          NOTE_CONTENT
        end
      end

      context 'with code suggestion' do
        let(:body) do
          <<~RESPONSE
          <review>
          <comment file="example.rb" old_line="1" new_line="2">
          First comment with suggestions
          <from>
              first offending line
          </from>
          <to>
              first improved line
          </to>
          Some more comments
          </comment>
          </review>
          RESPONSE
        end

        it 'returns the expected comment' do
          comment = parser.comments.sole
          expect(comment.file).to eq "example.rb"
          expect(comment.content).to eq <<~NOTE_CONTENT
          First comment with suggestions
          ```suggestion:-0+0
              first improved line
          ```
          Some more comments
          NOTE_CONTENT
        end

        context 'when <from> and <to> tags are inlined' do
          let(:body) do
            <<~RESPONSE
            <review>
            <comment file="example.rb" old_line="1" new_line="2">
            First comment with suggestions
            <from>    first offending line</from>
            <to>    first improved line</to>
            Some more comments
            </comment>
            </review>
            RESPONSE
          end

          it 'returns the expected comment' do
            comment = parser.comments.sole
            expect(comment.file).to eq "example.rb"
            expect(comment.content).to eq <<~NOTE_CONTENT
            First comment with suggestions
            ```suggestion:-0+0
                first improved line
            ```
            Some more comments
            NOTE_CONTENT
          end
        end

        context 'when the response contains a multiline suggestion' do
          let(:body) do
            <<~RESPONSE
            <review>
            <comment file="example.rb" old_line="1" new_line="2">
            First comment with a suggestion
            <from>
                first offending line
                second offending line
                third offending line
            </from>
            <to>
                first improved line
                second improved line
                  third improved line
                  fourth improved line
            </to>
            Some more comments
            </comment>
            </review>
            RESPONSE
          end

          it 'returns the expected comment' do
            comment = parser.comments.sole
            expect(comment.file).to eq "example.rb"
            expect(comment.content).to eq <<~NOTE_CONTENT
            First comment with a suggestion
            ```suggestion:-0+2
                first improved line
                second improved line
                  third improved line
                  fourth improved line
            ```
            Some more comments
            NOTE_CONTENT
          end
        end

        context 'when the response contains multiple comments for different files' do
          let(:body) do
            <<~RESPONSE
            <review>
            <comment file="example.rb" old_line="1" new_line="2">
            First comment with a suggestion
            <from>
                first offending line
            </from>
            <to>
                first improved line
            </to>
            </comment>
            <comment file="other.rb" old_line="" new_line="5">
            Second comment with a suggestion
            <from>
                first offending line
                second offending line
            </from>
            <to>
                second improved line
                third improved line
            </to>

            Some more comments
            </comment>
            </review>
            RESPONSE
          end

          it 'parses both comments correctly' do
            expect(parser.comments.count).to eq 2

            first_comment = parser.comments[0]
            expect(first_comment.old_line).to eq 1
            expect(first_comment.new_line).to eq 2
            expect(first_comment.file).to eq "example.rb"
            expect(first_comment.content).to eq <<~NOTE_CONTENT
            First comment with a suggestion
            ```suggestion:-0+0
                first improved line
            ```
            NOTE_CONTENT

            second_comment = parser.comments[1]
            expect(second_comment.old_line).to be_nil
            expect(second_comment.new_line).to be 5
            expect(second_comment.file).to eq "other.rb"
            expect(second_comment.content).to eq <<~NOTE_CONTENT
            Second comment with a suggestion
            ```suggestion:-0+1
                second improved line
                third improved line
            ```

            Some more comments
            NOTE_CONTENT
          end
        end

        context 'when the response contains multiple suggestions in one comment' do
          let(:body) do
            <<~RESPONSE
            <review>
            <comment file="example.rb" old_line="1" new_line="2">
            First comment with a suggestion
            <from>
                first offending line
            </from>
            <to>
                first improved line
            </to>

            Alternative suggestion
            <from>
                first offending line
                second offending line
            </from>
            <to>
                second improved line
                third improved line
            </to>

            Some more comments
            </comment>
            </review>
            RESPONSE
          end

          it 'parses both suggestions correctly' do
            comment = parser.comments.sole
            expect(comment.file).to eq "example.rb"
            expect(comment.content).to eq <<~NOTE_CONTENT
            First comment with a suggestion
            ```suggestion:-0+0
                first improved line
            ```

            Alternative suggestion
            ```suggestion:-0+1
                second improved line
                third improved line
            ```

            Some more comments
            NOTE_CONTENT
          end
        end

        context 'when the content includes other elements' do
          let(:body) do
            <<~RESPONSE
              <review>
              <comment file="example.rb" old_line="" new_line="2">
              <from>
                  <div>first offending line</div>
                    <p>second offending line</p>
              </from>
              <to>
                  <div>first improved line</div>
                    <p>second improved line</p>
              </to>
              </comment>
              </review>
            RESPONSE
          end

          it 'returns the expected comment' do
            comment = parser.comments.sole
            expect(comment.file).to eq "example.rb"
            expect(comment.content).to eq <<~NOTE_CONTENT
              ```suggestion:-0+1
                  <div>first improved line</div>
                    <p>second improved line</p>
              ```
            NOTE_CONTENT
          end
        end

        context 'when the content includes <from> and <to>' do
          let(:body) do
            <<~RESPONSE
              <review>
              <comment file="example.rb" old_line="" new_line="2">
              <from>
                  <from>first offending line</from>
                  <to>second offending line</to>
              </from>
              <to>
                  <from>first improved line</from>
                  <to>second improved line</to>
              </to>
              </comment>
              </review>
            RESPONSE
          end

          it 'returns the expected comment' do
            comment = parser.comments.sole
            expect(comment.file).to eq "example.rb"
            expect(comment.content).to eq <<~NOTE_CONTENT
              ```suggestion:-0+1
                  <from>first improved line</from>
                  <to>second improved line</to>
              ```
            NOTE_CONTENT
          end
        end

        context 'when the content includes <from>' do
          let(:body) do
            <<~RESPONSE
              <review>
              <comment file="example.rb" old_line="1" new_line="2">
              Some comment including a <from> tag
              <from>
                  <from>
                    Old
                  </from>
              </from>
              <to>
                  <from>
                    New
                  </from>
              </to>
              </comment>
              </review>
            RESPONSE
          end

          it 'returns the expected comment' do
            comment = parser.comments.sole
            expect(comment.file).to eq "example.rb"
            expect(comment.content).to eq <<~NOTE_CONTENT
              Some comment including a <from> tag
              ```suggestion:-0+2
                  <from>
                    New
                  </from>
              ```
            NOTE_CONTENT
          end
        end

        context 'when the suggestion contains any reserved XML characters' do
          let(:body) do
            <<~RESPONSE
            <review>
            <comment file="example.rb" old_line="1" new_line="2">
            First comment with suggestions
            <from>
              a && b
            </from>
            <to>
              a && b < c
            </to>
            </comment>
            </review>
            RESPONSE
          end

          it 'returns the expected comment' do
            comment = parser.comments.sole
            expect(comment.file).to eq "example.rb"
            expect(comment.content).to eq <<~NOTE_CONTENT
            First comment with suggestions
            ```suggestion:-0+0
              a && b < c
            ```
            NOTE_CONTENT
          end
        end

        context 'when the code suggestion contains line breaks only' do
          let(:body) do
            <<~RESPONSE
            <review>
            <comment file="example.rb" old_line="1" new_line="2">
            Please remove extra lines
            <from>



            </from>
            <to>

            </to>
            </comment>
            </review>
            RESPONSE
          end

          it 'returns the expected comment' do
            comment = parser.comments.sole
            expect(comment.file).to eq "example.rb"
            expect(comment.content).to eq <<~NOTE_CONTENT
            Please remove extra lines
            ```suggestion:-0+2

            ```
            NOTE_CONTENT
          end
        end

        context 'when the comment include only <to> tag' do
          let(:body) do
            <<~RESPONSE
              <review>
              <comment file="example.rb" old_line="" new_line="2">
              First comment with suggestions
              <to>
                  something random
              </to>
              Some more comments
              </comment>
              </review>
            RESPONSE
          end

          it 'returns the expected comment' do
            comment = parser.comments.sole
            expect(comment.file).to eq "example.rb"
            expect(comment.content).to eq <<~NOTE_CONTENT
              First comment with suggestions
              <to>
                  something random
              </to>
              Some more comments
            NOTE_CONTENT
          end
        end

        context 'when the response includes contents outside of <review> tag' do
          let(:body) do
            <<~RESPONSE
              Let me explain how awesome this review is.

              <review>
              <comment file="example.rb" old_line="" new_line="2">
              Example comment
              </comment>
              </review>
            RESPONSE
          end

          it 'returns the expected comment' do
            comment = parser.comments.sole
            expect(comment.file).to eq "example.rb"
            expect(comment.content).to eq <<~NOTE_CONTENT
              Example comment
            NOTE_CONTENT
          end
        end
      end

      context 'when review has a description' do
        let(:body) do
          <<~RESPONSE
          <review>
          The changes in this MR update the security e2e test metadata by:

          1. Renaming the test category from "Govern" to "Software Supply Chain Security" across multiple test files

          <comment file="example.rb" old_line="1" new_line="2">
          First comment with suggestions
          <from>
              first offending line
          </from>
          <to>
              first improved line
          </to>
          Some more comments
          </comment>
          </review>
          RESPONSE
        end

        it 'returns the expected review description' do
          review_description = parser.review_description
          expect(review_description).to eq <<~REVIEW_DESCRIPTION.chomp
          The changes in this MR update the security e2e test metadata by:

          1. Renaming the test category from "Govern" to "Software Supply Chain Security" across multiple test files
          REVIEW_DESCRIPTION
        end
      end

      context 'when review is in a single line' do
        let(:body) do
          <<~RESPONSE
          <review>Some text</review>
          RESPONSE
        end

        it 'returns the expected review description' do
          review_description = parser.review_description
          expect(review_description).to eq "Some text"
        end
      end

      context 'when review does not have content' do
        let(:body) do
          <<~RESPONSE
          <review>
          </review>
          RESPONSE
        end

        it 'returns the expected review description' do
          review_description = parser.review_description
          expect(review_description).to be_nil
        end
      end

      context 'when response does not have review tag' do
        let(:body) do
          <<~RESPONSE
          RESPONSE
        end

        it 'returns the expected review description' do
          review_description = parser.review_description
          expect(review_description).to be_nil
        end
      end

      context 'when response have content outside of review tag' do
        let(:body) do
          <<~RESPONSE
          this is text without <review> tag
          RESPONSE
        end

        it 'returns the expected review description' do
          review_description = parser.review_description
          expect(review_description).to be_nil
        end
      end

      context 'when review does not have a description' do
        let(:body) do
          <<~RESPONSE
          <review>
          <comment file="example.rb" old_line="1" new_line="2">
          First comment with suggestions
          <from>
              first offending line
          </from>
          <to>
              first improved line
          </to>
          Some more comments
          </comment>
          </review>
          RESPONSE
        end

        it 'returns the expected review description' do
          review_description = parser.review_description
          expect(review_description).to be_nil
        end
      end
    end

    context 'when the review content is empty' do
      let(:body) { "<review></review>" }

      it 'returns an empty array' do
        expect(parser.comments).to be_blank
      end
    end

    context 'when the body is nil' do
      let(:body) { nil }

      it 'returns an empty array' do
        expect(parser.comments).to be_blank
      end
    end

    context 'when the body is empty string' do
      let(:body) { '' }

      it 'returns an empty array' do
        expect(parser.comments).to be_blank
      end
    end

    context 'when <comment> tag is missing' do
      let(:body) { "<review>some random text</review>" }

      it 'returns an empty array' do
        expect(parser.comments).to be_blank
      end
    end

    context 'when attributes are missing' do
      let(:body) do
        <<~RESPONSE
          <review>
          <comment>
          Example comment
          </comment>
          </review>
        RESPONSE
      end

      it 'returns expected output' do
        expect(parser.comments).to be_blank
      end
    end

    context 'when line attributes are missing' do
      let(:body) do
        <<~RESPONSE
          <review>
          <comment file="example.rb">
          Example comment
          </comment>
          </review>
        RESPONSE
      end

      it 'returns expected output' do
        expect(parser.comments).to be_empty
      end
    end

    context 'when file attribute is missing' do
      let(:body) do
        <<~RESPONSE
          <review>
          <comment old_line="1" new_line="2">
          Example comment
          </comment>
          </review>
        RESPONSE
      end

      it 'returns expected output' do
        expect(parser.comments).to be_empty
      end
    end
  end
end
