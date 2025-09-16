# frozen_string_literal: true

require "spec_helper"

RSpec.describe Geo::EventWorker, :geo, feature_category: :geo_replication do
  let(:payload) { { 'model_record_id' => 1 } }

  subject(:worker) { described_class.new }

  describe "#perform" do
    let(:event_service) { instance_double(::Geo::EventService) }
    let(:replicable_name) { 'package_file' }
    let(:event_name) { 'created' }
    let(:job_args) { [replicable_name, event_name, payload] }

    before do
      allow(event_service).to receive(:execute)
      allow(::Geo::EventService).to receive(:new).with(*job_args).at_least(1).time.and_return(event_service)
    end

    it_behaves_like 'an idempotent worker' do
      it "calls Geo::EventService" do
        expect(event_service).to receive(:execute).exactly(worker_exec_times).times

        perform_idempotent_work
      end
    end

    it 'uses the correlation ID from the payload' do
      correlation_id = 'abc123'
      payload_with_correlation = payload.merge('correlation_id' => correlation_id)

      expect(Labkit::Correlation::CorrelationId).to receive(:use_id).with(correlation_id)

      worker.perform(replicable_name, event_name, payload_with_correlation)
    end

    it 'uses current or new correlation ID when not present in payload' do
      current_id = 'current123'
      allow(Labkit::Correlation::CorrelationId).to receive(:current_or_new_id).and_return(current_id)

      expect(Labkit::Correlation::CorrelationId).to receive(:use_id).with(current_id)

      worker.perform(replicable_name, event_name, payload)
    end
  end

  describe '#correlation_id' do
    it 'returns the correlation_id from the payload when present' do
      correlation_id = 'abc123'
      payload_with_correlation = payload.merge('correlation_id' => correlation_id)

      expect(worker.send(:correlation_id, payload_with_correlation)).to eq(correlation_id)
    end

    it 'returns the current or new correlation ID when not present in payload' do
      current_id = 'current123'
      allow(Labkit::Correlation::CorrelationId).to receive(:current_or_new_id).and_return(current_id)

      expect(worker.send(:correlation_id, payload)).to eq(current_id)
    end

    it 'calls current_or_new_id when correlation_id is not in payload' do
      expect(Labkit::Correlation::CorrelationId).to receive(:current_or_new_id)

      worker.send(:correlation_id, payload)
    end
  end
end
