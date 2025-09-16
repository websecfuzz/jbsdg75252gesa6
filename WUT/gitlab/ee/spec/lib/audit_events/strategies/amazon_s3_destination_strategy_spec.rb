# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::Strategies::AmazonS3DestinationStrategy, feature_category: :audit_events do
  let_it_be(:group) { create(:group) }
  let_it_be(:event) { create(:audit_event, :group_event, target_group: group) }

  let_it_be(:event_type) { 'project_name_updated' }

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

      context 'when Amazon S3 configurations does not exist for the group' do
        it { is_expected.to be_falsey }
      end

      context 'when Amazon S3 configurations exists for the group' do
        before do
          create(:amazon_s3_configuration, group: group)
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

    context 'when Amazon S3 configurations exist for the group' do
      it 'returns all the destinations' do
        destination1 = create(:amazon_s3_configuration, group: group)
        destination2 = create(:amazon_s3_configuration, group: group)

        expect(subject).to match_array([destination1, destination2])
      end
    end
  end

  it_behaves_like 'validate Amazon S3 destination strategy' do
    let!(:destination) { create(:amazon_s3_configuration, group: group) }
  end
end
