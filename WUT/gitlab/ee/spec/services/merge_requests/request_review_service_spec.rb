# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::MergeRequests::RequestReviewService, feature_category: :code_review_workflow do
  let_it_be(:current_user) { create(:user) }
  let_it_be(:user) { ::Users::Internal.duo_code_review_bot }
  let_it_be(:merge_request) { create(:merge_request, reviewers: [user]) }
  let(:service) { described_class.new(project: merge_request.project, current_user: current_user) }

  before_all do
    merge_request.project.add_developer(current_user)
  end

  context 'when requesting review from duo code review bot' do
    before do
      allow(merge_request.merge_request_diff).to receive_messages(
        persisted?: persisted,
        empty?: empty
      )

      allow(merge_request).to receive(:ai_review_merge_request_allowed?)
        .with(current_user)
        .and_return(ai_review_allowed)
    end

    context 'when AI review feature is not allowed' do
      let(:ai_review_allowed) { false }
      let(:persisted) { true }
      let(:empty) { false }

      it 'does not call ::Llm::ReviewMergeRequestService' do
        expect(Llm::ReviewMergeRequestService).not_to receive(:new)

        response = service.execute(merge_request, user)
        expect(response[:status]).to eq :error
        expect(response[:message]).to include "Your account doesn't have GitLab Duo access."
      end
    end

    context 'when AI review feature is allowed' do
      let(:ai_review_allowed) { true }
      let(:empty) { false }

      context 'when merge_request_diff is not persisted yet' do
        let(:persisted) { false }

        it 'does not call ::Llm::ReviewMergeRequestService' do
          expect(Llm::ReviewMergeRequestService).not_to receive(:new)

          service.execute(merge_request, user)
        end
      end

      context 'when merge_request_diff is persisted' do
        let(:persisted) { true }

        it 'calls ::Llm::ReviewMergeRequestService' do
          expect_next_instance_of(Llm::ReviewMergeRequestService, current_user, merge_request) do |svc|
            expect(svc).to receive(:execute)
          end

          service.execute(merge_request, user)
        end

        context 'when merge_request_diff is empty' do
          let(:empty) { true }

          it 'does not call ::Llm::ReviewMergeRequestService' do
            expect(Llm::ReviewMergeRequestService).not_to receive(:new)

            service.execute(merge_request, user)
          end
        end
      end
    end
  end
end
