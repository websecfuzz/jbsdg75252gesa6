# frozen_string_literal: true

RSpec.shared_examples 'common ai_usage_event' do
  it { is_expected.to belong_to(:user) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:user_id) }
    it { is_expected.to validate_presence_of(:timestamp) }

    it 'allows 3 month old data at the most' do
      is_expected.not_to allow_value(5.months.ago).for(:timestamp).with_message(_('must be 3 months old at the most'))
    end
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

  describe '#to_clickhouse_csv_row', :freeze_time do
    let(:event) { described_class.new(attributes.with_indifferent_access) }
    let(:attributes) do
      { user: user, timestamp: '2021-01-01'.to_datetime,
        event: described_class.events.each_key.first, namespace_path: '1/2' }
    end

    let(:user) { build_stubbed(:user) }

    it 'returns 3 required fields' do
      expect(event.to_clickhouse_csv_row).to include(
        user_id: user.id,
        timestamp: '2021-01-01'.to_datetime.to_f.round(3),
        event: described_class.events.each_value.first,
        namespace_path: '1/2'
      )
    end
  end

  describe '.related_event?' do
    it 'is true for events from events enum' do
      expect(described_class.related_event?(described_class.events.each_key.first)).to be_truthy
      expect(described_class.related_event?('unrelated_event')).to be_falsey
    end
  end
end
