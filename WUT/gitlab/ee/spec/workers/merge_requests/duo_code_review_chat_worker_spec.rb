# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::DuoCodeReviewChatWorker, feature_category: :code_review_workflow do
  subject(:worker) { described_class.new }

  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }

  let(:note_type) { :diff_note_on_merge_request }
  let(:note_content) { "@#{::Users::Internal.duo_code_review_bot.username} Hello!" }
  let(:expected_note_content) { ::Gitlab::Llm::Utils::CodeSuggestionFormatter.append_prompt(note.note) }

  let!(:first_discussion_note) do
    create(
      note_type,
      noteable: merge_request,
      project: project,
      author: ::Users::Internal.duo_code_review_bot,
      note: 'This is a review comment from Gitlab Duo'
    )
  end

  let!(:excluded_note) do
    create(
      note_type,
      noteable: merge_request,
      project: project,
      discussion_id: first_discussion_note.discussion_id,
      note: 'I am not mentioning GitLab Duo so I should be excluded'
    )
  end

  let(:note) do
    create(
      note_type,
      noteable: merge_request,
      project: project,
      discussion_id: first_discussion_note.discussion_id,
      note: note_content
    )
  end

  describe '#perform' do
    let(:chat_message) { instance_double(Gitlab::Llm::ChatMessage) }

    let(:response_modifier) do
      instance_double(
        Gitlab::Llm::Chain::ResponseModifier,
        response_body: 'chat response'
      )
    end

    let(:additional_context) do
      {
        id: note.latest_diff_file_path,
        category: 'file',
        content: note.raw_truncated_diff_lines
      }
    end

    before do
      allow_next_instance_of(
        Gitlab::Llm::Completions::Chat,
        an_object_having_attributes(content: expected_note_content),
        nil,
        additional_context: additional_context
      ) do |chat|
        allow(chat)
          .to receive(:execute)
          .and_return(response_modifier)
      end
    end

    shared_examples 'performing a Duo Code Review chat request' do
      it 'creates progress note and then note based on chat response' do
        expect(Gitlab::Llm::ChatMessage)
          .to receive(:new)
          .with(
            chat_message_params(
              ::Gitlab::Llm::AiMessage::ROLE_ASSISTANT,
              merge_request,
              first_discussion_note.note
            )
          )
          .and_call_original

        expect(Gitlab::Llm::ChatMessage)
          .not_to receive(:new)
          .with(
            chat_message_params(
              ::Gitlab::Llm::AiMessage::ROLE_USER,
              merge_request,
              excluded_note.note
            )
          )

        expect(Gitlab::Llm::ChatMessage)
          .to receive(:new)
          .with(
            chat_message_params(
              ::Gitlab::Llm::AiMessage::ROLE_USER,
              merge_request,
              expected_note_content
            )
          )
          .and_call_original

        progress_note_service = instance_double(::SystemNotes::MergeRequestsService)
        progress_note = instance_double(Note, destroy: true)

        expect(::SystemNotes::MergeRequestsService)
          .to receive(:new)
          .with(
            noteable: merge_request,
            container: merge_request.project,
            author: Users::Internal.duo_code_review_bot
          )
          .and_return(progress_note_service)
          .ordered

        expect(progress_note_service).to receive(:duo_code_review_chat_started).and_return(progress_note)

        expect(Notes::CreateService)
          .to receive(:new)
          .with(
            project,
            ::Users::Internal.duo_code_review_bot,
            hash_including(
              noteable: merge_request,
              note: response_modifier.response_body,
              in_reply_to_discussion_id: note.discussion_id,
              type: note.type
            )
          )
          .and_call_original
          .ordered

        worker.perform(note)
      end

      context 'when an error gets raised' do
        let(:error_note) do
          s_("DuoCodeReview|I encountered some problems while responding to your query. Please try again later.")
        end

        before do
          allow(::Gitlab::Llm::ChatMessage).to receive(:new).and_raise('error')
        end

        it 'creates progress note and error note' do
          progress_note_service = instance_double(::SystemNotes::MergeRequestsService)
          progress_note = instance_double(Note, destroy: true)

          expect(::SystemNotes::MergeRequestsService)
            .to receive(:new)
            .with(
              noteable: merge_request,
              container: merge_request.project,
              author: Users::Internal.duo_code_review_bot
            )
            .and_return(progress_note_service)
            .ordered

          expect(progress_note_service).to receive(:duo_code_review_chat_started).and_return(progress_note)

          expect(Notes::CreateService)
            .to receive(:new)
            .with(
              project,
              ::Users::Internal.duo_code_review_bot,
              hash_including(
                noteable: merge_request,
                note: error_note,
                in_reply_to_discussion_id: note.discussion_id,
                type: note.type
              )
            )
            .and_call_original
            .ordered

          worker.perform(note)
        end
      end

      context 'when note cannot be found' do
        it 'does not create note' do
          expect(Notes::CreateService).not_to receive(:new)

          worker.perform(note.id + 1)
        end
      end

      context 'when note does not mention GitLab Duo' do
        let(:note_content) { 'Hello' }

        it 'does not create note' do
          expect(Notes::CreateService).not_to receive(:new)

          worker.perform(note.id)
        end
      end

      context 'when chat response is blank' do
        let(:response_modifier) do
          instance_double(
            Gitlab::Llm::Chain::ResponseModifier,
            response_body: ''
          )
        end

        it 'creates progress note but no response note' do
          progress_note_service = instance_double(::SystemNotes::MergeRequestsService)
          progress_note = instance_double(Note, destroy: true)

          expect(::SystemNotes::MergeRequestsService)
            .to receive(:new)
            .with(
              noteable: merge_request,
              container: merge_request.project,
              author: Users::Internal.duo_code_review_bot
            )
            .and_return(progress_note_service)
            .ordered

          expect(progress_note_service).to receive(:duo_code_review_chat_started).and_return(progress_note)

          worker.perform(note.id)
        end
      end
    end

    it_behaves_like 'performing a Duo Code Review chat request'

    context 'when the response body includes code suggestion' do
      let(:response_modifier) do
        instance_double(
          Gitlab::Llm::Chain::ResponseModifier,
          response_body: response_body
        )
      end

      let(:response_body) do
        <<~RESPONSE
        Comment with suggestions
        <from>
          first offending line
            second offending line
        </from>
        <to>
          first improved line
            second improved line
        </to>
        Some more comments
        RESPONSE
      end

      it 'creates progress note and then parses code suggestions' do
        progress_note_service = instance_double(::SystemNotes::MergeRequestsService)
        progress_note = instance_double(Note, destroy: true)

        expect(::SystemNotes::MergeRequestsService)
          .to receive(:new)
          .with(
            noteable: merge_request,
            container: merge_request.project,
            author: Users::Internal.duo_code_review_bot
          )
          .and_return(progress_note_service)
          .ordered

        expect(progress_note_service).to receive(:duo_code_review_chat_started).and_return(progress_note)

        expect(Notes::CreateService)
          .to receive(:new)
          .with(
            project,
            ::Users::Internal.duo_code_review_bot,
            hash_including(
              noteable: merge_request,
              in_reply_to_discussion_id: note.discussion_id,
              type: note.type
            )
          )
          .and_call_original
          .ordered

        worker.perform(note.id)

        expect(Note.last.note).to eq <<~NOTE_CONTENT
        Comment with suggestions
        ```suggestion:-0+1
          first improved line
            second improved line
        ```
        Some more comments
        NOTE_CONTENT
      end
    end

    context 'when the note is not a diff note' do
      let(:expected_note_content) { note.note }
      let(:note_type) { :discussion_note_on_merge_request }
      let(:additional_context) do
        {
          id: 'reference',
          category: 'merge_request',
          content: "!#{merge_request.iid}"
        }
      end

      it_behaves_like 'performing a Duo Code Review chat request'
    end

    describe 'event tracking' do
      it 'tracks mention event when a note mentions GitLab Duo' do
        note_with_mention = create(
          :note,
          project: project,
          noteable: merge_request,
          note: "@#{::Users::Internal.duo_code_review_bot.username} can you review this?"
        )

        allow(worker).to receive_messages(
          create_progress_note: instance_double(Note, destroy: true),
          prepare_prompt_message: instance_double(Note, destroy: true),
          execute_chat_request: instance_double(Gitlab::Llm::Chain::ResponseModifier, response_body: 'response'),
          create_note_on: nil
        )

        expect { worker.perform(note_with_mention.id) }
          .to trigger_internal_events('mention_gitlabduo_in_mr_comment')
          .with(user: note_with_mention.author, project: note_with_mention.project)
          .and increment_usage_metrics('counts.count_total_mention_gitlabduo_in_mr_comment')
      end
    end
  end

  def chat_message_params(role, resource, content)
    {
      ai_action: 'chat',
      user: note.author,
      content: content,
      role: role,
      context: an_object_having_attributes(resource: resource),
      thread: an_instance_of(::Ai::Conversation::Thread)
    }
  end
end
