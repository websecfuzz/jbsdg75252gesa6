# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::SelfSigned::AccessDataReader, feature_category: :plan_provisioning do
  describe '#read_available_services' do
    let(:access_data_reader) { described_class.new }
    let(:access_data) do
      {
        services: {
          duo_chat: {
            cut_off_date: '2024-02-15 00:00:00 UTC',
            bundled_with: {
              add_on_1: {
                unit_primitives: %w[duo_chat]
              }
            },
            backend: 'ai_gateway'
          }
        }
      }.deep_stringify_keys
    end

    subject(:available_services) { access_data_reader.read_available_services }

    before do
      allow(access_data_reader).to receive(:access_record_data).and_return(access_data)
    end

    it 'parses the service data correctly' do
      expect(available_services).to include({
        duo_chat: be_instance_of(CloudConnector::SelfSigned::AvailableServiceData)
      })
    end

    it 'configures AvailableServiceData objects correctly' do
      expect(available_services[:duo_chat].name).to eq(:duo_chat)
      expect(available_services[:duo_chat].cut_off_date).to eq(Time.zone.parse("2024-02-15 00:00:00 UTC"))
      expect(available_services[:duo_chat].add_on_names).to match_array(%w[add_on_1])
    end
  end
end
