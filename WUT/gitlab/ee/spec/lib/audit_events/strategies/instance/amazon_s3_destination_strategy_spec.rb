# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::Strategies::Instance::AmazonS3DestinationStrategy, feature_category: :audit_events do
  let_it_be(:group) { create(:group) }
  let_it_be(:event) { create(:audit_event, :group_event, target_group: group) }
  let_it_be(:event_type) { 'project_name_updated' }

  describe '#streamable?' do
    subject(:streamable?) { described_class.new(event_type, event).streamable? }

    context 'when feature is not licensed' do
      it { is_expected.to be_falsey }
    end

    context 'when feature is licensed' do
      before do
        stub_licensed_features(external_audit_events: true)
      end

      context 'when instance Amazon S3 configurations does not exist' do
        it { is_expected.to be_falsey }
      end

      context 'when instance Amazon S3 configurations exists' do
        before do
          create(:instance_amazon_s3_configuration)
        end

        it { is_expected.to be_truthy }
      end
    end
  end

  describe '#destinations' do
    subject(:destinations) { described_class.new(event_type, event).send(:destinations) }

    context 'when there is no destination' do
      it 'returns empty array' do
        expect(destinations).to eq([])
      end
    end

    context 'when instance Amazon S3 configurations exist' do
      it 'returns all the destinations' do
        destination1 = create(:instance_amazon_s3_configuration)
        destination2 = create(:instance_amazon_s3_configuration)

        expect(destinations).to match_array([destination1, destination2])
      end
    end
  end

  it_behaves_like 'validate Amazon S3 destination strategy' do
    let!(:destination) { create(:instance_amazon_s3_configuration) }
  end
end
