# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Tools::SummarizeComments::ExecutorOld, feature_category: :duo_chat do
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:issue) { create(:issue, project: project) }

  let(:ai_request_double) { instance_double(Gitlab::Llm::Chain::Requests::AiGateway) }
  let(:input) { 'input' }
  let(:options) { { input: input } }
  let(:prompt_class) { Gitlab::Llm::Chain::Tools::SummarizeComments::Prompts::Anthropic }
  let(:resource) { issue }
  let(:context) do
    Gitlab::Llm::Chain::GitlabContext.new(
      current_user: user, container: project, resource: resource, ai_request: ai_request_double
    )
  end

  subject(:tool) { described_class.new(context: context, options: options) }

  before_all do
    group.add_developer(user)
  end

  before do
    allow(Ability).to receive(:allowed?).and_call_original
    allow(Ability).to receive(:allowed?).with(user, :summarize_comments, resource).and_return(true)

    allow(tool).to receive(:provider_prompt_class).and_return(prompt_class)

    stub_application_setting(check_namespace_plan: true)
    stub_licensed_features(summarize_comments: true, ai_features: true, experimental_features: true, ai_chat: true)

    group.update!(experiment_features_enabled: true)
  end

  describe '#name' do
    it 'returns tool name' do
      expect(described_class::NAME).to eq('SummarizeComments')
    end
  end

  describe '#description' do
    it 'returns tool description' do
      desc = 'This tool is useful when you need to create a summary ' \
        'of all notes, comments or discussions on a given, identified resource.'

      expect(described_class::DESCRIPTION).to include(desc)
    end
  end

  describe '#execute', :saas do
    include_context 'with stubbed LLM authorizer', allowed: true

    context 'when issue is identified' do
      context 'when user has permission to read resource' do
        context 'when resource has no comments to summarize' do
          it 'responds without making an AI call' do
            expect(tool).not_to receive(:request)
            response = "Issue ##{issue.iid} has no comments to be summarized."
            expect(tool.execute.content).to eq(response)
          end
        end

        context 'when resource has comments to summarize' do
          let!(:note) { create_pair(:note_on_issue, project: project, noteable: issue) }

          context 'when no permissions to use ai features' do
            before do
              allow(Ability).to receive(:allowed?).with(user, :summarize_comments, issue).and_return(false)
            end

            it 'responds with error' do
              expect(tool).not_to receive(:request)

              answer = tool.execute
              response = "I'm sorry, I can't generate a response. You might want to try again. " \
                "You could also be getting this error because the items you're asking about " \
                "either don't exist, you don't have access to them, or your session has expired."

              expect(answer.content).to eq(response)
              expect(answer.error_code).to eq("M3003")
            end
          end

          context 'when resource was already summarized' do
            before do
              context.tools_used << described_class
            end

            it 'returns already summarized response' do
              expect(tool).not_to receive(:request)

              response = "You already have the summary of the notes, comments, discussions for the " \
                "Issue ##{issue.iid} in your context, read carefully."
              expect(tool.execute.content).to include(response)
            end
          end

          it 'responds with summary' do
            expect(tool).to receive(:request).and_return("some response")

            response = "Here is the summary for Issue #1 comments:"
            expect(tool.execute.content).to include(response)
          end

          context 'with raw_ai_response: true' do
            let(:options) { { input: "user input", suggestions: "", raw_ai_response: true } }

            it 'calls given block with chunks' do
              expect(tool).to receive(:request).and_yield("some").and_yield(" response")
              expect { |b| tool.execute(&b) }.to yield_successive_args("some", " response")
            end

            it 'returns content when no block is given' do
              expect(tool).to receive(:request).and_return('some response')
              expect(tool.execute.content).to eq('some response')
            end

            context 'with a script tag in the comments' do
              let(:note_input) do
                'This is a note on how to update gitlab <script>malicious_code()</script>. There is ' \
                  'also an image tag <img SRC="img.jpg" alt="Example Image" width="500" height="600"> ' \
                  'here.'
              end

              let!(:note) { create(:note_on_issue, project: project, noteable: issue, note: note_input) }

              it 'removes the script tag from the notes' do
                allow(tool).to receive(:request)
                tool.execute
                expect(tool.instance_variable_get(:@options)[:notes_content]).to eq(
                  "<comment>This is a note on how to update gitlab . There is also an image tag  here.</comment>")
              end
            end
          end
        end
      end
    end
  end
end
