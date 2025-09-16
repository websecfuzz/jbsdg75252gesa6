# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Clusters::Agents::AutoFlow::MergeRequests::ClosedEventWorker, feature_category: :deployment_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:merge_request) { create(:merge_request, target_project: project, source_project: project) }
  let_it_be(:event) do
    ::MergeRequests::ClosedEvent.new(
      data: { merge_request_id: merge_request.id }
    )
  end

  subject(:handle_event) { consume_event(subscriber: described_class, event: event) }

  before do
    allow(Gitlab::Kas).to receive(:enabled?).and_return(true)

    allow_next_instance_of(Gitlab::Kas::Client) do |instance|
      allow(instance).to receive(:send_autoflow_event)
    end

    allow(SecureRandom).to receive(:uuid)
      .and_return('42')
  end

  it_behaves_like 'subscribes to event'

  it 'sends the event to AutoFlow' do
    expect_next_instance_of(Gitlab::Kas::Client) do |instance|
      expect(instance).to receive(:send_autoflow_event)
        .with(
          project: project,
          id: '42',
          type: described_class::AUTOFLOW_EVENT_TYPE,
          data: {
            project: {
              id: project.id
            },
            merge_request: {
              id: merge_request.id,
              iid: merge_request.iid
            }
          }
        )
        .and_return(nil)
    end

    handle_event
  end
end
