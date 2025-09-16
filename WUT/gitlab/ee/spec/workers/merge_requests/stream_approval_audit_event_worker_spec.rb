# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::StreamApprovalAuditEventWorker, feature_category: :code_review_workflow do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }

  let(:data) { { current_user_id: user.id, merge_request_id: merge_request.id, approved_at: Time.current.iso8601 } }
  let(:approved_event) { MergeRequests::ApprovedEvent.new(data: data) }

  it_behaves_like 'subscribes to event' do
    let(:event) { approved_event }
  end

  it 'calls MergeRequests::SteamApprovalAuditEventService' do
    expect_next_instance_of(
      MergeRequests::StreamApprovalAuditEventService,
      project: project, current_user: user
    ) do |service|
      expect(service).to receive(:execute).with(merge_request)
    end

    consume_event(subscriber: described_class, event: approved_event)
  end

  shared_examples 'when object does not exist' do
    it 'logs and does not call MergeRequests::SteamApprovalAuditEventService' do
      expect(Sidekiq.logger).to receive(:info).with(hash_including(log_payload))
      expect(MergeRequests::StreamApprovalAuditEventService).not_to receive(:new)

      expect { consume_event(subscriber: described_class, event: approved_event) }
        .not_to raise_exception
    end
  end

  context 'when the user does not exist' do
    before do
      user.destroy!
    end

    it_behaves_like 'when object does not exist' do
      let(:log_payload) { { 'message' => 'Current user not found.', 'current_user_id' => user.id } }
    end
  end

  context 'when the merge request does not exist' do
    before do
      merge_request.destroy!
    end

    it_behaves_like 'when object does not exist' do
      let(:log_payload) { { 'message' => 'Merge request not found.', 'merge_request_id' => merge_request.id } }
    end
  end
end
