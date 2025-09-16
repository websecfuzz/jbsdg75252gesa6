# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::UsageEvent, feature_category: :value_stream_management do
  subject(:event) { described_class.new(attributes) }

  let(:attributes) { { event: 'troubleshoot_job' } }
  let_it_be(:personal_namespace) { create(:namespace) }
  let_it_be(:user) { create(:user, namespace: personal_namespace, organizations: [personal_namespace.organization]) }

  it { is_expected.to belong_to(:user) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:user_id) }
    it { is_expected.to validate_presence_of(:timestamp) }
    it { is_expected.to validate_presence_of(:organization_id) }

    it 'allows 3 month old data at the most' do
      is_expected.not_to allow_value(5.months.ago).for(:timestamp).with_message(_('must be 3 months old at the most'))
    end
  end

  describe '#organization_id' do
    subject(:event) { described_class.new(user: user) }

    it { is_expected.to populate_sharding_key(:organization_id).with(personal_namespace.organization.id) }
  end

  describe '#timestamp', :freeze_time do
    it 'defaults to current time' do
      expect(event.timestamp).to eq(DateTime.current)
    end

    it 'properly converts from string' do
      expect(described_class.new(timestamp: DateTime.current.to_s).timestamp).to eq(DateTime.current)
    end
  end

  describe '#before_validation' do
    it 'floors timestamp to 3 digits' do
      event = described_class.new(timestamp: '2021-01-01 01:02:03.123456789'.to_datetime)
      expect do
        event.validate
      end.to change { event.timestamp }.to('2021-01-01 01:02:03.123'.to_datetime)
    end
  end

  describe '#store_to_pg', :freeze_time do
    context 'when the model is invalid' do
      it 'does not add anything to write buffer' do
        expect(Ai::UsageEventWriteBuffer).not_to receive(:add)

        event.store_to_pg
      end
    end

    context 'when the model is valid' do
      let(:attributes) do
        super().merge(namespace: personal_namespace, user: user, timestamp: 1.day.ago)
      end

      it 'adds model attributes to write buffer' do
        expect(Ai::UsageEventWriteBuffer).to receive(:add)
                                               .with('Ai::UsageEvent', {
                                                 event: 'troubleshoot_job',
                                                 timestamp: 1.day.ago,
                                                 user_id: user.id,
                                                 organization_id: user.organizations.first.id,
                                                 namespace_id: personal_namespace.id,
                                                 extras: {}
                                               }.with_indifferent_access)

        event.store_to_pg
      end
    end
  end

  describe '#store_to_clickhouse', :freeze_time do
    context 'when the model is invalid' do
      it 'does not add anything to write buffer' do
        expect(ClickHouse::WriteBuffer).not_to receive(:add)

        event.store_to_clickhouse
      end
    end

    context 'when the model is valid' do
      let(:attributes) do
        super().merge(user: user, namespace: personal_namespace, timestamp: 1.day.ago, extras: { foo: 'bar' })
      end

      it 'adds model attributes to write buffer' do
        expect(ClickHouse::WriteBuffer).to receive(:add)
                                             .with('ai_usage_events', {
                                               event: described_class.events['troubleshoot_job'],
                                               timestamp: 1.day.ago.to_f,
                                               user_id: user.id,
                                               namespace_path: personal_namespace.traversal_path,
                                               extras: { foo: 'bar' }.to_json
                                             })

        event.store_to_clickhouse
      end
    end
  end
end
