# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::DeleteProjectEventWorker, :zoekt_settings_enabled, feature_category: :global_search do
  let(:project_deleted_event) { Projects::ProjectDeletedEvent.new(data: data) }
  let_it_be(:project) { create(:project, :repository) }
  let(:data) do
    { project_id: project.id, namespace_id: project.namespace_id, root_namespace_id: project.root_namespace.id }
  end

  before do
    allow(::Search::Zoekt).to receive(:delete_async).and_return(true)
  end

  it_behaves_like 'subscribes to event' do
    let(:event) { project_deleted_event }
  end

  it 'schedules deletion operation' do
    expect(::Search::Zoekt).to receive(:delete_async).with(project.id, root_namespace_id: project.root_namespace.id)
    consume_event(subscriber: described_class, event: project_deleted_event)
  end
end
