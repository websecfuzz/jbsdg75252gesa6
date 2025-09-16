# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::CleanupBuildNameWorker, feature_category: :continuous_integration do
  let_it_be(:very_old_build) { create(:ci_build, :failed, :with_build_name, created_at: 1.year.ago) }
  let_it_be(:slightly_old_build) { create(:ci_build, :success, :with_build_name, created_at: 4.months.ago) }
  let_it_be(:build_right_before_3_months_cut_off) do
    create(:ci_build, :success, :with_build_name, created_at: 3.months.ago - 1.day)
  end

  let_it_be(:new_build) { create(:ci_build, :with_build_name, created_at: 1.day.ago) }

  describe '#perform' do
    subject(:worker) { described_class.new }

    it 'deletes build name records older than 3 months' do
      expect(Ci::Build.count).to eq(4)
      expect(Ci::BuildName.count).to eq(4)

      worker.perform

      expect(Ci::Build.count).to eq(4)
      expect(Ci::BuildName.ids).to match_array([new_build.id])
    end

    context 'with no records found' do
      before do
        stub_const("#{described_class}::CUT_OFF_DATE", 24)
      end

      it 'returns if there are no records to be deleted' do
        worker.perform

        expect(Ci::Build.count).to eq(4)
        expect(Ci::BuildName.count).to eq(4)
      end
    end

    context 'with batches' do
      before do
        stub_const("#{described_class}::BATCH_SIZE", 2)
      end

      it 'performs deletes in multiple batches' do
        sql_queries = ActiveRecord::QueryRecorder.new { worker.perform }.log
        delete_count = sql_queries.count { |query| query.start_with?('DELETE') }

        expect(delete_count).to eq(2)

        expect(Ci::BuildName.ids).to match_array([new_build.id])
      end
    end

    context 'when runtime limit is reached' do
      before do
        stub_const("#{described_class}::BATCH_SIZE", 2)

        allow_next_instance_of(Gitlab::Metrics::RuntimeLimiter) do |runtime_limiter|
          allow(runtime_limiter).to receive(:over_time?).and_return(true)
        end
      end

      it 'reschedules the worker' do
        expect(described_class).to receive(:perform_in).with(2.minutes)

        worker.perform
      end

      it 'does not finish deleting all the records' do
        worker.perform

        expect(Ci::BuildName.count).to eq(2)
      end
    end

    context 'with FF disabled' do
      before do
        stub_feature_flags(truncate_build_names: false)
      end

      it 'no-ops' do
        worker.perform

        expect(Ci::Build.count).to eq(4)
        expect(Ci::BuildName.count).to eq(4)
      end
    end
  end
end
