# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoChatEvent, feature_category: :value_stream_management do
  subject(:event) { described_class.new(attributes) }

  let(:attributes) { { event: 'request_duo_chat_response' } }
  let_it_be(:personal_namespace) { create(:namespace) }
  let_it_be(:user) { create(:user, namespace: personal_namespace, organizations: [personal_namespace.organization]) }

  it_behaves_like 'common ai_usage_event'

  describe '.payload_attributes' do
    it 'is empty' do
      expect(described_class.payload_attributes).to be_empty
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:organization_id) }
  end

  describe '#organization_id' do
    subject(:event) { described_class.new(user: user) }

    it { is_expected.to populate_sharding_key(:organization_id).with(personal_namespace.organization.id) }
  end

  describe '#personal_namespace_id' do
    subject(:event) { described_class.new(user: user).tap(&:valid?) }

    it 'populates personal_namespace_id from user namespace' do
      expect(event.personal_namespace_id).to eq(personal_namespace.id)
    end
  end

  describe '#to_clickhouse_csv_row', :freeze_time do
    let(:attributes) do
      super().merge(user: user, timestamp: 1.day.ago)
    end

    it 'returns serialized attributes hash' do
      expect(event.to_clickhouse_csv_row).to eq({
        user_id: user.id,
        event: described_class.events[:request_duo_chat_response],
        namespace_path: nil,
        timestamp: 1.day.ago.to_f
      })
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
        super().merge(user: user, timestamp: 1.day.ago)
      end

      it 'adds model attributes to write buffer' do
        expect(Ai::UsageEventWriteBuffer).to receive(:add)
                                               .with('Ai::DuoChatEvent', {
                                                 event: 'request_duo_chat_response',
                                                 timestamp: 1.day.ago,
                                                 user_id: user.id,
                                                 personal_namespace_id: personal_namespace.id,
                                                 organization_id: user.organizations.first.id
                                               }.with_indifferent_access)

        event.store_to_pg
      end
    end
  end
end
