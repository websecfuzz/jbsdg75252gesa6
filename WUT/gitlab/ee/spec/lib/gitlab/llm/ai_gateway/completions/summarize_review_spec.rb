# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::AiGateway::Completions::SummarizeReview, feature_category: :code_review_workflow do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }
  let_it_be(:draft_note_by_random_user) { create(:draft_note, merge_request: merge_request) }

  let(:prompt_class) { Gitlab::Llm::Templates::SummarizeReview }
  let(:options) { {} }

  let(:prompt_message) do
    build(:ai_message, :summarize_review, user: user, resource: merge_request, request_id: 'uuid')
  end

  let(:model_metadata) { nil }

  subject(:resolve) { described_class.new(prompt_message, prompt_class, options) }

  describe '#root_namespace' do
    context 'when the target project is in a subgroup' do
      let_it_be(:group) { create(:group) }
      let_it_be(:subgroup) { create(:group, parent: group) }
      let_it_be(:project) { create(:project, :repository, group: subgroup) }
      let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }

      it 'returns the root namespace' do
        expect(resolve.root_namespace).to eq(group)
      end
    end

    context 'when the target project is in a group at the root level' do
      let_it_be(:group) { create(:group) }
      let_it_be(:project) { create(:project, :repository, group: group) }
      let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }

      it 'returns the root namespace' do
        expect(resolve.root_namespace).to eq(group)
      end
    end

    context 'when the target project is in a user namespace' do
      it 'returns the root namespace' do
        expect(resolve.root_namespace).to eq(project.root_namespace)
      end
    end
  end

  describe '#execute' do
    before do
      stub_feature_flags(ai_model_switching: false)
      stub_feature_flags(use_claude_code_completion: false)
    end

    shared_examples_for 'summarize review with prompt version' do
      it 'includes prompt_version in the request' do
        expect_next_instance_of(Gitlab::Llm::AiGateway::Client) do |client|
          expect(client)
            .to receive(:complete_prompt)
            .with(
              base_url: Gitlab::AiGateway.url,
              prompt_name: :summarize_review,
              inputs: { draft_notes_content: draft_notes_content },
              model_metadata: model_metadata,
              prompt_version: prompt_version
            )
            .and_return(example_response)
        end

        resolve.execute
      end
    end

    context 'when there are no draft notes authored by user' do
      it 'does not make AI request' do
        expect(Gitlab::Llm::AiGateway::Client).not_to receive(:new)

        resolve.execute
      end
    end

    context 'when there are draft notes authored by user' do
      let_it_be(:draft_note_by_current_user) do
        create(
          :draft_note,
          merge_request: merge_request,
          author: user,
          note: 'This is a draft note'
        )
      end

      let(:example_answer) { "AI generated review summary" }
      let(:example_response) { instance_double(HTTParty::Response, body: example_answer.to_json, success?: true) }

      shared_examples_for 'summarize review' do
        it 'publishes the content from the AI response' do
          expect_next_instance_of(Gitlab::Llm::AiGateway::Client) do |client|
            allow(client)
              .to receive(:complete_prompt)
              .with(
                base_url: Gitlab::AiGateway.url,
                prompt_name: :summarize_review,
                inputs: { draft_notes_content: draft_notes_content },
                model_metadata: model_metadata,
                prompt_version: "2.1.0"
              )
              .and_return(example_response)
          end

          expect(::Gitlab::Llm::GraphqlSubscriptionResponseService).to receive(:new).and_call_original
          expect(resolve.execute[:ai_message].content).to eq(example_answer)
        end
      end

      context 'when draft notes passed as options' do
        let(:draft_note) do
          build(
            :draft_note,
            merge_request: merge_request,
            author: user,
            note: 'This is a draft note from options'
          )
        end

        let(:draft_notes_content) { "Comment: #{draft_note.note}\n" }
        let(:options) { { draft_notes: [draft_note] } }

        it_behaves_like 'summarize review'
      end

      context 'when draft note content length fits INPUT_CONTENT_LIMIT' do
        let(:draft_notes_content) { "Comment: #{draft_note_by_current_user.note}\n" }

        it_behaves_like 'summarize review'
      end

      context 'when draft note content length is longer than INPUT_CONTENT_LIMIT' do
        let(:draft_notes_content) { "" }

        before do
          stub_const("#{described_class}::INPUT_CONTENT_LIMIT", 2)
        end

        it_behaves_like 'summarize review'
      end

      context 'when use_claude_code_completion feature flag is enabled for the root namespace of the merge request' do
        let_it_be(:group) { create(:group) }
        let_it_be(:project) { create(:project, :repository, group: group) }
        let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }
        let_it_be(:draft_note_by_current_user) do
          create(
            :draft_note,
            merge_request: merge_request,
            author: user,
            note: 'This is a draft note'
          )
        end

        before do
          stub_feature_flags(use_claude_code_completion: group)
        end

        it_behaves_like 'summarize review with prompt version' do
          let(:prompt_version) { '1.0.0' }
        end
      end

      context 'when namespace model switching is enabled' do
        let(:draft_notes_content) { "Comment: #{draft_note_by_current_user.note}\n" }
        let(:prompt_version) { "2.1.0" }
        let_it_be(:group) { create(:group) }
        let_it_be(:project) { create(:project, :repository, group: group) }
        let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }
        let_it_be(:draft_note_by_current_user) do
          create(
            :draft_note,
            merge_request: merge_request,
            author: user,
            note: 'This is a draft note'
          )
        end

        before do
          stub_feature_flags(ai_model_switching: true)
        end

        context 'when the model is pinned to a specific model' do
          before do
            create(:ai_namespace_feature_setting,
              namespace: group,
              feature: 'summarize_review'
            )
          end

          it_behaves_like 'summarize review with prompt version' do
            let(:model_metadata) do
              {
                feature_setting: 'summarize_review',
                identifier: 'claude_sonnet_3_7',
                provider: 'gitlab'
              }
            end
          end
        end
      end
    end
  end
end
