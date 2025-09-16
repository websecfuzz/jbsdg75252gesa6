# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::SyncTimeoutCronWorker, :geo, feature_category: :geo_replication do
  describe '#perform' do
    it 'calls fail_sync_timeouts' do
      replicator = double('replicator')

      expect(replicator).to receive(:fail_sync_timeouts)
      expect(Gitlab::Geo).to receive(:replication_enabled_replicator_classes).and_return([replicator])

      described_class.new.perform
    end
  end

  it 'uses a cronjob queue' do
    expect(subject.sidekiq_options_hash).to include(
      'queue_namespace' => :cronjob
    )
  end
end
