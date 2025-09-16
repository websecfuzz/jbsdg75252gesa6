# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::UsageDataCounters do
  describe '.usage_data_counters' do
    subject { described_class.counters }

    it { is_expected.to all(respond_to :totals) }
    it { is_expected.to all(respond_to :fallback_totals) }
  end

  describe '.count' do
    subject { described_class.count(event_name) }

    let(:event_name) { 'i_code_review_merge_request_widget_code_quality_count_view' }

    it 'increases a searches counter' do
      expect(Gitlab::UsageDataCounters::MergeRequestWidgetExtensionCounter)
        .to receive(:count).with('code_quality_count_view')

      subject
    end

    context 'when event_name is not defined' do
      let(:event_name) { 'unknown' }

      it 'raises an exception' do
        expect { subject }.to raise_error(Gitlab::UsageDataCounters::UnknownEvent)
      end
    end
  end
end
