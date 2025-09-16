# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::SelfManaged::AccessDataReader, feature_category: :plan_provisioning do
  describe '#read_available_services' do
    subject(:available_services) { described_class.new.read_available_services }

    let(:service_start_time) { Time.zone.parse("2024-02-15 00:00:00 UTC") }

    context 'when available_services element exists' do
      let(:data) do
        {
          available_services: [
            {
              "name" => "duo_chat",
              "serviceStartTime" => service_start_time,
              "bundledWith" => %w[add_on_1 add_on_2]
            }
          ]
        }
      end

      before do
        create(:cloud_connector_access, data: data)
      end

      it 'parses the data hash into AvailableServiceData objects' do
        expect(available_services).to match({
          duo_chat: be_instance_of(CloudConnector::SelfManaged::AvailableServiceData)
        })
      end

      it 'configures AvailableServiceData objects correctly' do
        expect(available_services[:duo_chat].name).to eq(:duo_chat)
        expect(available_services[:duo_chat].cut_off_date).to eq(Time.zone.parse("2024-02-15 00:00:00 UTC"))
        expect(available_services[:duo_chat].add_on_names).to match_array(%w[add_on_1 add_on_2])
      end

      context 'when cut-off date is not set' do
        let(:service_start_time) { nil }

        it 'sets cut-off-date to nil' do
          expect(available_services[:duo_chat].cut_off_date).to be_nil
        end
      end
    end

    context 'when available_services element does not exist' do
      let(:data) { {} }

      it 'returns an empty hash' do
        expect(available_services).to eq({})
      end
    end

    context 'when available_services element is empty' do
      let(:data) { { available_services: nil } }

      it 'returns an empty hash' do
        expect(available_services).to eq({})
      end
    end
  end
end
