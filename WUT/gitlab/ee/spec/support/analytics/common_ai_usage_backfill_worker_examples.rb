# frozen_string_literal: true

RSpec.shared_examples 'common ai usage backfill worker' do |model|
  subject(:worker) { described_class.new }

  let(:event) { Analytics::ClickHouseForAnalyticsEnabledEvent.new(data: { enabled_at: 1.day.ago.iso8601 }) }

  before do
    create(:application_setting)
  end

  def perform
    worker.perform(event.class.name, event.data)
  end

  it_behaves_like 'an idempotent worker'

  context 'when clickhouse is not configured' do
    it 'records disabled status' do
      perform

      expect(worker).to log_extra_metadata_on_done(result: { status: :disabled })
    end
  end

  describe '#perform', :click_house, :freeze_time do
    context 'when clickhouse for analytics is not enabled' do
      before do
        stub_application_setting(use_clickhouse_for_analytics: false)
      end

      it 'records disabled status' do
        perform

        expect(worker).to log_extra_metadata_on_done(result: { status: :disabled })
      end
    end

    context 'when clickhouse for analytics is enabled' do
      before do
        stub_application_setting(use_clickhouse_for_analytics: true)
      end

      let(:ch_records) do
        ClickHouse::Client.select("SELECT * FROM #{model.clickhouse_table_name} FINAL ORDER BY timestamp", :main)
      end

      it 'inserts all records to ClickHouse' do
        perform

        expect(ch_records).to match_array(expected_ch_events)
      end

      it "doesn't reschedule itself" do
        expect(described_class).not_to receive(:perform_in)

        perform
      end

      it "doesn't create duplicates when data already exists in CH" do
        existing_ch_records

        perform

        # assumes that existing_ch_records has only 1 non-duplicate
        expect(ch_records.size).to eq(pg_events.size + 1)
      end

      context 'when time limit is reached' do
        before do
          stub_const("ClickHouse::SyncStrategies::BaseSyncStrategy::BATCH_SIZE", 1)

          allow_next_instance_of(Gitlab::Metrics::RuntimeLimiter) do |runtime_limiter|
            allow(runtime_limiter).to receive(:over_time?).and_return(false, true)
          end
        end

        it 'stops the processing' do
          perform

          expect(worker).to log_extra_metadata_on_done(
            result: { status: :processed, records_inserted: 2, reached_end_of_table: false }
          )
          expect(ch_records.size).to eq(2)
        end

        it 'reschedules the worker in 1 minute' do
          expect(described_class).to receive(:perform_in).with(1.minute, event.class.name, event.data)

          perform
        end
      end
    end
  end
end
