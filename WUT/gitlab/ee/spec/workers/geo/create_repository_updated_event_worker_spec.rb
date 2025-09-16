# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::CreateRepositoryUpdatedEventWorker, feature_category: :geo_replication do
  include ::EE::GeoHelpers
  include AfterNextHelpers

  let_it_be(:primary_site) { create(:geo_node, :primary) }
  let_it_be(:secondary_site) { create(:geo_node) }
  let_it_be(:project) { create(:project, :repository) }

  let(:event) { ::Repositories::KeepAroundRefsCreatedEvent.new(data: { project_id: project.id }) }

  subject { consume_event(subscriber: described_class, event: event) }

  context 'on a Geo primary site' do
    before do
      stub_current_geo_node(primary_site)
    end

    it_behaves_like 'subscribes to event'

    it 'consumes the published event', :sidekiq_inline do
      expect_next(described_class)
        .to receive(:handle_event)
        .with(instance_of(event.class))
        .and_call_original

      expect do
        ::Gitlab::EventStore.publish(event)
      end.to change { ::Geo::Event.where(event_name: :updated).count }.by(1)
    end
  end
end
