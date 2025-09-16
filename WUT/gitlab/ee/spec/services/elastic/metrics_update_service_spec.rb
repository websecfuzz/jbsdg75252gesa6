# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Elastic::MetricsUpdateService, :prometheus, feature_category: :global_search do
  subject { described_class.new }

  describe '#execute' do
    it 'sets gauges' do
      expect(Elastic::ProcessBookkeepingService).to receive(:queue_size).and_return(4).twice
      expect(Elastic::ProcessInitialBookkeepingService).to receive(:queue_size).and_return(6).twice
      expect(Search::Elastic::ProcessEmbeddingBookkeepingService).to receive(:queue_size).and_return(5).once

      incremental_gauge_double = instance_double(Prometheus::Client::Gauge)
      expect(Gitlab::Metrics).to receive(:gauge)
        .with(:search_advanced_bulk_cron_queue_size, anything, {}, :max)
        .and_return(incremental_gauge_double)

      initial_gauge_double = instance_double(Prometheus::Client::Gauge)
      expect(Gitlab::Metrics).to receive(:gauge)
        .with(:search_advanced_bulk_cron_initial_queue_size, anything, {}, :max)
        .and_return(initial_gauge_double)

      embedding_gauge_double = instance_double(Prometheus::Client::Gauge)
      expect(Gitlab::Metrics).to receive(:gauge)
        .with(:search_advanced_bulk_cron_embedding_queue_size, anything, {}, :max)
        .and_return(embedding_gauge_double)

      expect(incremental_gauge_double).to receive(:set).with({}, 4)
      expect(initial_gauge_double).to receive(:set).with({}, 6)
      expect(embedding_gauge_double).to receive(:set).with({}, 5)

      # deprecated metrics

      incremental_gauge_deprecated_double = instance_double(Prometheus::Client::Gauge)
      expect(Gitlab::Metrics).to receive(:gauge)
        .with(:global_search_bulk_cron_queue_size, anything, {}, :max)
        .and_return(incremental_gauge_deprecated_double)

      initial_gauge_deprecated_double = instance_double(Prometheus::Client::Gauge)
      expect(Gitlab::Metrics).to receive(:gauge)
        .with(:global_search_bulk_cron_initial_queue_size, anything, {}, :max)
        .and_return(initial_gauge_deprecated_double)

      expect(incremental_gauge_deprecated_double).to receive(:set).with({}, 4)
      expect(initial_gauge_deprecated_double).to receive(:set).with({}, 6)

      subject.execute
    end
  end
end
