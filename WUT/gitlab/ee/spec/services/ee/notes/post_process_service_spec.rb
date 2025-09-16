# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Notes::PostProcessService, feature_category: :team_planning do
  describe '#execute' do
    context 'analytics' do
      subject { described_class.new(note) }

      let(:note) { create(:note) }
      let(:analytics_mock) { instance_double('Analytics::RefreshCommentsData') }

      it 'invokes Analytics::RefreshCommentsData' do
        allow(Analytics::RefreshCommentsData).to receive(:for_note).with(note).and_return(analytics_mock)

        expect(analytics_mock).to receive(:execute)

        subject.execute
      end
    end

    context 'for audit events' do
      subject(:notes_post_process_service) { described_class.new(note) }

      context 'when note author is a project bot' do
        let_it_be(:project_bot) { create(:user, :project_bot, email: "bot@example.com") }

        let(:note) { create(:note, author: project_bot) }

        it 'audits with correct name' do
          # Stub .audit here so that only relevant audit events are received below
          allow(::Gitlab::Audit::Auditor).to receive(:audit)

          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(name: "comment_by_project_bot", stream_only: true)
          ).and_call_original

          notes_post_process_service.execute
        end

        it 'does not persist the audit event to database' do
          expect { notes_post_process_service.execute }.not_to change { AuditEvent.count }
        end
      end

      context 'when note author is not a project bot' do
        let(:note) { create(:note) }

        it 'does not invoke Gitlab::Audit::Auditor' do
          expect(::Gitlab::Audit::Auditor).not_to receive(:audit).with(hash_including(
            name: 'comment_by_project_bot'
          ))

          notes_post_process_service.execute
        end

        it 'does not create an audit event' do
          expect { notes_post_process_service.execute }.not_to change { AuditEvent.count }
        end
      end
    end

    context 'for processing Duo Code Review chat' do
      let_it_be(:project) { create(:project, :repository) }
      let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }
      let_it_be(:note) { create(:diff_note_on_merge_request, noteable: merge_request, project: project) }

      subject(:execute) { described_class.new(note).execute }

      shared_examples_for 'not enqueueing MergeRequests::DuoCodeReviewChatWorker' do
        it 'does not enqueue MergeRequests::DuoCodeReviewChatWorker' do
          expect(::MergeRequests::DuoCodeReviewChatWorker).not_to receive(:perform_async)

          execute
        end
      end

      before do
        allow(merge_request).to receive(:ai_review_merge_request_allowed?).and_return(true)
        allow(note).to receive(:duo_bot_mentioned?).and_return(true)
      end

      it 'enqueues MergeRequests::DuoCodeReviewChatWorker' do
        expect(::MergeRequests::DuoCodeReviewChatWorker).to receive(:perform_async).with(note.id)

        execute
      end

      context 'when note is authored by GitLab Duo' do
        before do
          allow(note).to receive(:authored_by_duo_bot?).and_return(true)
        end

        it_behaves_like 'not enqueueing MergeRequests::DuoCodeReviewChatWorker'
      end

      context 'when MergeRequest#ai_review_merge_request_allowed? returns false' do
        before do
          allow(merge_request).to receive(:ai_review_merge_request_allowed?).and_return(false)
        end

        it_behaves_like 'not enqueueing MergeRequests::DuoCodeReviewChatWorker'
      end

      context 'when Note#duo_bot_mentioned? returns false' do
        before do
          allow(note).to receive(:duo_bot_mentioned?).and_return(false)
        end

        it_behaves_like 'not enqueueing MergeRequests::DuoCodeReviewChatWorker'
      end
    end
  end
end
