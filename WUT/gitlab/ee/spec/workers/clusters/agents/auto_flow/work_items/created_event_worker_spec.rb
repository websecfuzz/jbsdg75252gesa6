# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Clusters::Agents::AutoFlow::WorkItems::CreatedEventWorker, feature_category: :deployment_management do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:work_item) { create(:work_item, :issue, project: project) }
  let_it_be(:event) do
    ::WorkItems::WorkItemCreatedEvent.new(
      data: { id: work_item.id, namespace_id: work_item.namespace_id }
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
            issue: {
              id: work_item.id,
              iid: work_item.iid
            }
          }
        )
        .and_return(nil)
    end

    handle_event
  end
end
