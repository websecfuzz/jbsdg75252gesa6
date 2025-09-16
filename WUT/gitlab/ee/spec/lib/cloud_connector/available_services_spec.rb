# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::AvailableServices, feature_category: :plan_provisioning do
  let(:feature_name) { :duo_chat }

  describe '.select_reader' do
    subject { described_class.select_reader(feature_name) }

    context 'when .com', :saas do
      it 'returns SelfSigned::AccessDataReader' do
        is_expected.to be_a_kind_of(CloudConnector::SelfSigned::AccessDataReader)
      end
    end

    context 'when CLOUD_CONNECTOR_SELF_SIGN_TOKENS is set' do
      before do
        stub_env('CLOUD_CONNECTOR_SELF_SIGN_TOKENS', '1')
      end

      it 'returns SelfSigned::AccessDataReader' do
        is_expected.to be_a_kind_of(CloudConnector::SelfSigned::AccessDataReader)
      end
    end

    context 'when the AI gateway service is self-hosted' do
      it 'returns SelfManaged::AccessDataReader if CLOUD_CONNECTOR_SELF_SIGN_TOKENS is disabled' do
        is_expected.to be_a_kind_of(CloudConnector::SelfManaged::AccessDataReader)
      end

      context 'when CLOUD_CONNECTOR_SELF_SIGN_TOKENS is enabled' do
        before do
          stub_env('CLOUD_CONNECTOR_SELF_SIGN_TOKENS', '1')
        end

        context 'when feature is self_hosted_models' do
          let(:feature_name) { :self_hosted_models }

          it 'returns SelfSigned::AccessDataReader' do
            is_expected.to be_a_kind_of(CloudConnector::SelfSigned::AccessDataReader)
          end
        end

        context 'when env is development' do
          it 'returns SelfSigned::AccessDataReader' do
            allow(Rails.env).to receive(:development?).and_return(true)

            is_expected.to be_a_kind_of(CloudConnector::SelfSigned::AccessDataReader)
          end
        end
      end
    end

    context 'when self_managed' do
      it 'returns SelfManaged::AccessDataReader' do
        is_expected.to be_a_kind_of(CloudConnector::SelfManaged::AccessDataReader)
      end
    end
  end

  describe '.find_by_name' do
    let(:access_data_reader) { ::CloudConnector::SelfManaged::AccessDataReader.new }

    before do
      allow(described_class).to receive(:select_reader).and_return(access_data_reader)
    end

    it 'reads available service' do
      available_services = { duo_chat: CloudConnector::BaseAvailableServiceData.new(:duo_chat, nil, nil) }
      expect(access_data_reader).to receive(:read_available_services).and_return(available_services)

      service = described_class.find_by_name(feature_name)

      expect(service.name).to eq(:duo_chat)
    end

    context 'when available_services is empty' do
      it 'returns null service data' do
        expect(access_data_reader).to receive(:read_available_services).and_return([])

        service = described_class.find_by_name(feature_name)

        expect(service.name).to eq(:missing_service)
        expect(service).to be_instance_of(CloudConnector::MissingServiceData)
      end
    end

    context 'when available_services does not contain the requested name' do
      it 'returns null service data' do
        available_services = { duo_chat: CloudConnector::BaseAvailableServiceData.new(:duo_chat, nil, nil) }
        expect(access_data_reader).to receive(:read_available_services).and_return(available_services)

        service = described_class.find_by_name(:service_name_that_is_not_synced_or_typo)

        expect(service.name).to eq(:missing_service)
        expect(service).to be_instance_of(CloudConnector::MissingServiceData)
      end
    end

    context 'when service is a self hosted service' do
      before do
        create(:ai_feature_setting, feature: :duo_chat, provider: :self_hosted)
      end

      context 'when feature is configured for self-hosted usage' do
        it 'fetches the self_hosted service' do
          expect(described_class).to receive(:select_reader).with(:self_hosted_models).and_return(access_data_reader)

          described_class.find_by_name(:include_issue_context)
        end
      end
    end
  end

  describe 'memoization behaviour' do
    let(:service_name) { :duo_chat }

    context 'with Self-Signed reader', :saas do
      it 'returns the same object instance on subsequent calls',
        quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/545272' do
        first  = described_class.find_by_name(service_name)
        second = described_class.find_by_name(service_name)

        expect(first).to equal(second)
      end
    end

    context 'with Self-Managed reader', :with_cloud_connector do
      it 'returns a new object instance on each call' do
        first  = described_class.find_by_name(service_name)
        second = described_class.find_by_name(service_name)

        expect(first).not_to equal(second)
      end
    end
  end
end
