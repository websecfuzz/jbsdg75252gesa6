# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::Strategies::GoogleCloudLoggingDestinationStrategy, feature_category: :audit_events do
  let(:group) { build(:group) }
  let(:event) { build(:audit_event, :group_event, target_group: group) }

  let_it_be(:event_type) { 'audit_operation' }
  let_it_be(:request_body) { { key: "value" }.to_json }

  describe '#streamable?' do
    subject { described_class.new(event_type, event).streamable? }

    context 'when feature is not licensed' do
      it { is_expected.to be_falsey }
    end

    context 'when feature is licensed' do
      before do
        stub_licensed_features(external_audit_events: true)
      end

      context 'when event group is nil' do
        let_it_be(:event) { build(:audit_event) }

        it { is_expected.to be_falsey }
      end

      context 'when group google cloud logging configurations does not exist' do
        it { is_expected.to be_falsey }
      end

      context 'when group google cloud logging configurations exist' do
        before do
          create(:google_cloud_logging_configuration, group: group)
        end

        it { is_expected.to be_truthy }
      end
    end
  end

  describe '#destinations' do
    subject { described_class.new(event_type, event).send(:destinations) }

    context 'when event group is nil' do
      let_it_be(:event) { build(:audit_event) }

      it 'returns empty array' do
        expect(subject).to eq([])
      end
    end

    context 'when group google cloud logging configurations exist' do
      it 'returns all the destinations' do
        destination1 = create(:google_cloud_logging_configuration, group: group)
        destination2 = create(:google_cloud_logging_configuration, group: group)

        expect(subject).to match_array([destination1, destination2])
      end
    end
  end

  it_behaves_like 'validate google cloud logging destination strategy' do
    let!(:destination) { create(:google_cloud_logging_configuration, group: group) }
  end
end
